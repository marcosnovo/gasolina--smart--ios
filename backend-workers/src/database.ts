// D1-backed data layer. Mirrors the public API of the Bun backend's
// database.ts so the rest of the worker can call it without caring about
// the underlying SQLite implementation.
//
// Key differences vs the Bun version:
// - D1 is async: every query returns a Promise.
// - D1 has no PRAGMAs and no synchronous transactions; we use db.batch()
//   for multi-statement atomic writes.
// - Foreign keys are not enforced, but the schema mirrors the original.

export interface StationInput {
  id: string;
  name: string;
  brand: string;
  address: string;
  municipality: string;
  province: string;
  latitude: number;
  longitude: number;
  prices: Record<string, number>;
  updatedAt: string;
}

export interface StationResult {
  id: string;
  name: string;
  brand: string;
  address: string;
  municipality: string;
  province: string;
  latitude: number;
  longitude: number;
  country: string;
  updated_at: string;
  distance_km: number;
  prices: Record<string, number>;
}

interface StationRow {
  id: string;
  name: string;
  brand: string;
  address: string;
  municipality: string;
  province: string;
  latitude: number;
  longitude: number;
  country: string;
  updated_at: string;
}

interface PriceRow {
  station_id: string;
  fuel_type: string;
  price: number;
}

// --- Haversine (km) ---

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// --- Writes ---

// Upserts stations + prices in chunks to stay within D1's 1000-statements-per-batch limit.
// Inserts a price_history row only when the price actually changed since the last upsert
// (cheaper than always writing — keeps us comfortably under the 100k writes/day free tier).
export async function saveStations(
  db: D1Database,
  country: string,
  stations: StationInput[]
): Promise<{ saved: boolean; count: number; historyInserts: number }> {
  if (stations.length === 0) {
    console.warn(`[db] saveStations(${country}): empty array, keeping previous data`);
    return { saved: false, count: 0, historyInserts: 0 };
  }

  const now = new Date().toISOString();

  // 1. Read existing prices in one query to diff against incoming prices.
  const ids = stations.map((s) => s.id);
  const existingPrices = await readExistingPrices(db, ids);

  // 2. Build the list of statements to batch.
  const stmts: D1PreparedStatement[] = [];
  let historyInserts = 0;

  for (const s of stations) {
    stmts.push(
      db
        .prepare(
          `INSERT INTO stations (id, name, brand, address, municipality, province, latitude, longitude, country, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT(id) DO UPDATE SET
             name = excluded.name, brand = excluded.brand, address = excluded.address,
             municipality = excluded.municipality, province = excluded.province,
             latitude = excluded.latitude, longitude = excluded.longitude,
             country = excluded.country, updated_at = excluded.updated_at`
        )
        .bind(
          s.id,
          s.name,
          s.brand,
          s.address,
          s.municipality,
          s.province,
          s.latitude,
          s.longitude,
          country,
          s.updatedAt
        )
    );

    const existing = existingPrices.get(s.id) ?? {};
    for (const [fuelType, price] of Object.entries(s.prices)) {
      stmts.push(
        db
          .prepare(
            `INSERT INTO prices (station_id, fuel_type, price, updated_at)
             VALUES (?, ?, ?, ?)
             ON CONFLICT(station_id, fuel_type) DO UPDATE SET
               price = excluded.price, updated_at = excluded.updated_at`
          )
          .bind(s.id, fuelType, price, s.updatedAt)
      );

      if (existing[fuelType] !== price) {
        stmts.push(
          db
            .prepare(
              `INSERT INTO price_history (station_id, fuel_type, price, recorded_at)
               VALUES (?, ?, ?, ?)`
            )
            .bind(s.id, fuelType, price, now)
        );
        historyInserts++;
      }
    }
  }

  stmts.push(
    db
      .prepare(
        `INSERT INTO country_meta (country, key, value) VALUES (?, ?, ?)
         ON CONFLICT(country, key) DO UPDATE SET value = excluded.value`
      )
      .bind(country, "last_fetch", now)
  );
  stmts.push(
    db
      .prepare(
        `INSERT INTO country_meta (country, key, value) VALUES (?, ?, ?)
         ON CONFLICT(country, key) DO UPDATE SET value = excluded.value`
      )
      .bind(country, "station_count", String(stations.length))
  );

  // 3. D1 batches up to ~1000 statements; chunk to be safe.
  const CHUNK = 500;
  for (let i = 0; i < stmts.length; i += CHUNK) {
    await db.batch(stmts.slice(i, i + CHUNK));
  }

  return { saved: true, count: stations.length, historyInserts };
}

async function readExistingPrices(
  db: D1Database,
  stationIds: string[]
): Promise<Map<string, Record<string, number>>> {
  if (stationIds.length === 0) return new Map();

  // D1 doesn't support array binding; chunk by IN-list size to stay readable.
  const CHUNK = 200;
  const out = new Map<string, Record<string, number>>();

  for (let i = 0; i < stationIds.length; i += CHUNK) {
    const slice = stationIds.slice(i, i + CHUNK);
    const placeholders = slice.map(() => "?").join(",");
    const res = await db
      .prepare(
        `SELECT station_id, fuel_type, price FROM prices WHERE station_id IN (${placeholders})`
      )
      .bind(...slice)
      .all<PriceRow>();

    for (const row of res.results) {
      let map = out.get(row.station_id);
      if (!map) {
        map = {};
        out.set(row.station_id, map);
      }
      map[row.fuel_type] = row.price;
    }
  }

  return out;
}

// --- Reads ---

export async function queryStationsNearby(
  db: D1Database,
  lat: number,
  lon: number,
  radiusKm: number,
  country: string = "ES",
  fuelType?: string,
  limit: number = 50
): Promise<StationResult[]> {
  const degLat = radiusKm / 111.0;
  const degLon = radiusKm / (111.0 * Math.cos((lat * Math.PI) / 180));

  let rows: StationRow[];

  if (fuelType) {
    const res = await db
      .prepare(
        `SELECT DISTINCT s.*
         FROM stations s
         JOIN prices p ON s.id = p.station_id AND p.fuel_type = ?
         WHERE s.country = ?
           AND s.latitude BETWEEN ? AND ?
           AND s.longitude BETWEEN ? AND ?`
      )
      .bind(fuelType, country, lat - degLat, lat + degLat, lon - degLon, lon + degLon)
      .all<StationRow>();
    rows = res.results;
  } else {
    const res = await db
      .prepare(
        `SELECT * FROM stations
         WHERE country = ?
           AND latitude BETWEEN ? AND ?
           AND longitude BETWEEN ? AND ?`
      )
      .bind(country, lat - degLat, lat + degLat, lon - degLon, lon + degLon)
      .all<StationRow>();
    rows = res.results;
  }

  const withDistance = rows
    .map((s) => ({ ...s, distance_km: haversineKm(lat, lon, s.latitude, s.longitude) }))
    .filter((s) => s.distance_km <= radiusKm)
    .sort((a, b) => a.distance_km - b.distance_km)
    .slice(0, limit);

  if (withDistance.length === 0) return [];

  const stationIds = withDistance.map((s) => s.id);
  const priceMap = await readExistingPrices(db, stationIds);

  return withDistance.map((s) => ({
    id: s.id,
    name: s.name,
    brand: s.brand,
    address: s.address,
    municipality: s.municipality,
    province: s.province,
    latitude: s.latitude,
    longitude: s.longitude,
    country: s.country,
    updated_at: s.updated_at,
    distance_km: Math.round(s.distance_km * 100) / 100,
    prices: priceMap.get(s.id) || {},
  }));
}

export async function queryCheapest(
  db: D1Database,
  lat: number,
  lon: number,
  radiusKm: number,
  fuelType: string,
  country: string = "ES"
): Promise<StationResult | null> {
  const results = await queryStationsNearby(db, lat, lon, radiusKm, country, fuelType, 500);
  if (results.length === 0) return null;

  return results.reduce((cheapest, s) => {
    const sPrice = s.prices[fuelType] ?? Infinity;
    const cPrice = cheapest.prices[fuelType] ?? Infinity;
    return sPrice < cPrice ? s : cheapest;
  });
}

export async function queryAveragePrice(
  db: D1Database,
  lat: number,
  lon: number,
  radiusKm: number,
  fuelType: string,
  country: string = "ES"
): Promise<{ average: number; count: number } | null> {
  const results = await queryStationsNearby(db, lat, lon, radiusKm, country, fuelType, 500);
  const prices = results
    .map((s) => s.prices[fuelType])
    .filter((p): p is number => p != null);

  if (prices.length === 0) return null;

  const sum = prices.reduce((a, b) => a + b, 0);
  return {
    average: Math.round((sum / prices.length) * 1000) / 1000,
    count: prices.length,
  };
}

export async function queryStationDetail(
  db: D1Database,
  stationId: string
): Promise<StationResult | null> {
  let resolvedId = stationId;
  if (!/^(ES|GB|FR|DE|IT)_/.test(stationId)) {
    resolvedId = `ES_${stationId}`;
  }

  const station = await db
    .prepare("SELECT * FROM stations WHERE id = ?")
    .bind(resolvedId)
    .first<StationRow>();

  if (!station) return null;

  const priceRes = await db
    .prepare("SELECT station_id, fuel_type, price FROM prices WHERE station_id = ?")
    .bind(resolvedId)
    .all<PriceRow>();

  const priceMap: Record<string, number> = {};
  for (const p of priceRes.results) priceMap[p.fuel_type] = p.price;

  return {
    ...station,
    distance_km: 0,
    prices: priceMap,
  };
}

export async function queryPriceHistory(
  db: D1Database,
  stationId: string,
  days: number = 30,
  limit: number = 1000
): Promise<Array<{ recorded_at: string; fuel_type: string; price: number }>> {
  let resolvedId = stationId;
  if (!/^(ES|GB|FR|DE|IT)_/.test(stationId)) {
    resolvedId = `ES_${stationId}`;
  }

  const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

  const res = await db
    .prepare(
      `SELECT recorded_at, fuel_type, price FROM price_history
       WHERE station_id = ? AND recorded_at >= ?
       ORDER BY recorded_at DESC
       LIMIT ?`
    )
    .bind(resolvedId, cutoff, limit)
    .all<{ recorded_at: string; fuel_type: string; price: number }>();

  return res.results;
}

export async function queryCountryStats(
  db: D1Database
): Promise<Array<{ country: string; station_count: number; last_fetched_at: string | null }>> {
  const countriesRes = await db
    .prepare("SELECT country, COUNT(*) as cnt FROM stations GROUP BY country ORDER BY country")
    .all<{ country: string; cnt: number }>();

  const out: Array<{ country: string; station_count: number; last_fetched_at: string | null }> = [];

  for (const c of countriesRes.results) {
    const meta = await db
      .prepare("SELECT value FROM country_meta WHERE country = ? AND key = 'last_fetch'")
      .bind(c.country)
      .first<{ value: string }>();

    out.push({
      country: c.country,
      station_count: c.cnt,
      last_fetched_at: meta?.value ?? null,
    });
  }

  return out;
}

export async function getCountryMetaValue(
  db: D1Database,
  country: string,
  key: string
): Promise<string | null> {
  const row = await db
    .prepare("SELECT value FROM country_meta WHERE country = ? AND key = ?")
    .bind(country, key)
    .first<{ value: string }>();
  return row?.value ?? null;
}

export async function setCountryMetaValue(
  db: D1Database,
  country: string,
  key: string,
  value: string
): Promise<void> {
  await db
    .prepare(
      `INSERT INTO country_meta (country, key, value) VALUES (?, ?, ?)
       ON CONFLICT(country, key) DO UPDATE SET value = excluded.value`
    )
    .bind(country, key, value)
    .run();
}
