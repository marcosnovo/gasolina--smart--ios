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

  // 3. D1 batches up to ~1000 statements; chunk to be safe.
  const CHUNK = 500;
  for (let i = 0; i < stmts.length; i += CHUNK) {
    await db.batch(stmts.slice(i, i + CHUNK));
  }

  // 4. After upserts settle, refresh `station_count` from the actual
  // table rather than from `stations.length`. The fetch run only
  // brings whatever subset survived rate limits / 503s, but upserts
  // accumulate in D1 — so the run's array length is meaningless as a
  // "stations available for this country" metric. Query post-batch.
  const countRow = await db
    .prepare(`SELECT COUNT(*) AS c FROM stations WHERE country = ?`)
    .bind(country)
    .first<{ c: number }>();
  const tableCount = countRow?.c ?? stations.length;
  await db
    .prepare(
      `INSERT INTO country_meta (country, key, value) VALUES (?, ?, ?)
       ON CONFLICT(country, key) DO UPDATE SET value = excluded.value`
    )
    .bind(country, "station_count", String(tableCount))
    .run();

  return { saved: true, count: stations.length, historyInserts };
}

async function readExistingPrices(
  db: D1Database,
  stationIds: string[]
): Promise<Map<string, Record<string, number>>> {
  if (stationIds.length === 0) return new Map();

  // D1 caps prepared-statement bound variables at 100 (vs SQLite's default 999).
  // Keep below that with a safety margin.
  const CHUNK = 90;
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

// Full-country dump: returns every station of a country with its price map.
// One indexed scan on stations + one JOIN on prices — no chunking required
// because we read the whole table sequentially rather than via IN-lists.
export async function queryAllStations(
  db: D1Database,
  country: string
): Promise<StationResult[]> {
  const stationsRes = await db
    .prepare(
      "SELECT * FROM stations WHERE country = ? ORDER BY id"
    )
    .bind(country)
    .all<StationRow>();

  if (stationsRes.results.length === 0) return [];

  const pricesRes = await db
    .prepare(
      `SELECT p.station_id, p.fuel_type, p.price
       FROM prices p
       JOIN stations s ON s.id = p.station_id
       WHERE s.country = ?`
    )
    .bind(country)
    .all<PriceRow>();

  const priceMap = new Map<string, Record<string, number>>();
  for (const row of pricesRes.results) {
    let map = priceMap.get(row.station_id);
    if (!map) {
      map = {};
      priceMap.set(row.station_id, map);
    }
    map[row.fuel_type] = row.price;
  }

  return stationsRes.results.map((s) => ({
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
    distance_km: 0,
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

export interface CountryStats {
  country: string;
  station_count: number;
  charging_count: number;
  last_fetched_at: string | null;
  charging_last_fetched_at: string | null;
}

export async function queryCountryStats(db: D1Database): Promise<CountryStats[]> {
  // Aggregate counts straight from the source tables — meta keys can be
  // stale or partially written, the row counts can't lie.
  const [fuelRes, chargingRes] = await Promise.all([
    db.prepare("SELECT country, COUNT(*) as cnt FROM stations GROUP BY country").all<{ country: string; cnt: number }>(),
    db.prepare("SELECT country, COUNT(*) as cnt FROM charging_stations GROUP BY country").all<{ country: string; cnt: number }>(),
  ]);

  const fuelMap = new Map(fuelRes.results.map((r) => [r.country, r.cnt]));
  const chargingMap = new Map(chargingRes.results.map((r) => [r.country, r.cnt]));
  const allCountries = new Set<string>([...fuelMap.keys(), ...chargingMap.keys()]);

  const out: CountryStats[] = [];
  for (const country of [...allCountries].sort()) {
    const lastFetch = await db
      .prepare("SELECT value FROM country_meta WHERE country = ? AND key = 'last_fetch'")
      .bind(country)
      .first<{ value: string }>();
    const chargingLastFetch = await db
      .prepare("SELECT value FROM country_meta WHERE country = ? AND key = 'charging_last_fetch'")
      .bind(country)
      .first<{ value: string }>();

    out.push({
      country,
      station_count: fuelMap.get(country) ?? 0,
      charging_count: chargingMap.get(country) ?? 0,
      last_fetched_at: lastFetch?.value ?? null,
      charging_last_fetched_at: chargingLastFetch?.value ?? null,
    });
  }

  return out;
}

// =============================================================================
// EV charging stations
// =============================================================================

export interface ChargingConnectionInput {
  typeName: string;
  powerKW: number | null;
  quantity: number | null;
}

export interface ChargingStationInput {
  id: string;
  name: string;
  operatorName: string | null;
  address: string;
  municipality: string;
  province: string;
  latitude: number;
  longitude: number;
  numberOfPoints: number;
  isOperational: boolean;
  usageCost: string | null;
  connections: ChargingConnectionInput[];
}

export interface ChargingStationResult {
  id: string;
  name: string;
  operator_name: string | null;
  address: string;
  municipality: string;
  province: string;
  latitude: number;
  longitude: number;
  country: string;
  number_of_points: number;
  is_operational: boolean;
  usage_cost: string | null;
  max_power_kw: number | null;
  connections: ChargingConnectionInput[];
  updated_at: string;
}

interface ChargingStationRow {
  id: string;
  name: string;
  operator_name: string | null;
  address: string;
  municipality: string;
  province: string;
  latitude: number;
  longitude: number;
  country: string;
  number_of_points: number;
  is_operational: number;
  usage_cost: string | null;
  max_power_kw: number | null;
  connectors_json: string;
  updated_at: string;
}

export async function saveChargingStations(
  db: D1Database,
  country: string,
  stations: ChargingStationInput[]
): Promise<{ saved: boolean; count: number }> {
  if (stations.length === 0) {
    console.warn(`[db] saveChargingStations(${country}): empty array, skipping`);
    return { saved: false, count: 0 };
  }

  const now = new Date().toISOString();
  const stmts: D1PreparedStatement[] = [];

  for (const s of stations) {
    const maxPower = s.connections
      .map((c) => c.powerKW)
      .filter((p): p is number => p != null)
      .reduce<number | null>((acc, v) => (acc == null || v > acc ? v : acc), null);

    stmts.push(
      db
        .prepare(
          `INSERT INTO charging_stations (id, name, operator_name, address, municipality, province,
             latitude, longitude, country, number_of_points, is_operational, usage_cost,
             max_power_kw, connectors_json, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT(id) DO UPDATE SET
             name = excluded.name, operator_name = excluded.operator_name,
             address = excluded.address, municipality = excluded.municipality,
             province = excluded.province, latitude = excluded.latitude,
             longitude = excluded.longitude, country = excluded.country,
             number_of_points = excluded.number_of_points,
             is_operational = excluded.is_operational, usage_cost = excluded.usage_cost,
             max_power_kw = excluded.max_power_kw, connectors_json = excluded.connectors_json,
             updated_at = excluded.updated_at`
        )
        .bind(
          s.id,
          s.name,
          s.operatorName,
          s.address,
          s.municipality,
          s.province,
          s.latitude,
          s.longitude,
          country,
          s.numberOfPoints,
          s.isOperational ? 1 : 0,
          s.usageCost,
          maxPower,
          JSON.stringify(s.connections),
          now
        )
    );
  }

  stmts.push(
    db
      .prepare(
        `INSERT INTO country_meta (country, key, value) VALUES (?, ?, ?)
         ON CONFLICT(country, key) DO UPDATE SET value = excluded.value`
      )
      .bind(country, "charging_last_fetch", now)
  );

  const CHUNK = 500;
  for (let i = 0; i < stmts.length; i += CHUNK) {
    await db.batch(stmts.slice(i, i + CHUNK));
  }

  // Same fix as saveStations: refresh charging_station_count from the
  // actual table count so it stays accurate across cron runs.
  const countRow = await db
    .prepare(`SELECT COUNT(*) AS c FROM charging_stations WHERE country = ?`)
    .bind(country)
    .first<{ c: number }>();
  const tableCount = countRow?.c ?? stations.length;
  await db
    .prepare(
      `INSERT INTO country_meta (country, key, value) VALUES (?, ?, ?)
       ON CONFLICT(country, key) DO UPDATE SET value = excluded.value`
    )
    .bind(country, "charging_station_count", String(tableCount))
    .run();

  return { saved: true, count: stations.length };
}

export async function queryAllChargingStations(
  db: D1Database,
  country: string
): Promise<ChargingStationResult[]> {
  const res = await db
    .prepare("SELECT * FROM charging_stations WHERE country = ? ORDER BY id")
    .bind(country)
    .all<ChargingStationRow>();

  return res.results.map((row) => ({
    id: row.id,
    name: row.name,
    operator_name: row.operator_name,
    address: row.address,
    municipality: row.municipality,
    province: row.province,
    latitude: row.latitude,
    longitude: row.longitude,
    country: row.country,
    number_of_points: row.number_of_points,
    is_operational: row.is_operational === 1,
    usage_cost: row.usage_cost,
    max_power_kw: row.max_power_kw,
    connections: parseConnectorsJSON(row.connectors_json),
    updated_at: row.updated_at,
  }));
}

function parseConnectorsJSON(raw: string): ChargingConnectionInput[] {
  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter((c): c is ChargingConnectionInput =>
      typeof c === "object" && c !== null && typeof c.typeName === "string"
    );
  } catch {
    return [];
  }
}

// =============================================================================
// Country meta
// =============================================================================

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
