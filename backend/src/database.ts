import { Database } from "bun:sqlite";
import { mkdirSync, existsSync } from "fs";
import { dirname } from "path";

const DB_PATH = process.env.DB_PATH || "./data/gasolina.db";

const dir = dirname(DB_PATH);
if (!existsSync(dir)) mkdirSync(dir, { recursive: true });

const db = new Database(DB_PATH, { create: true });

db.exec("PRAGMA journal_mode = WAL");
db.exec("PRAGMA synchronous = NORMAL");
db.exec("PRAGMA cache_size = -64000");

// --- Base tables (unchanged structure for new DBs) ---

db.exec(`
  CREATE TABLE IF NOT EXISTS stations (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    brand TEXT,
    address TEXT,
    municipality TEXT,
    province TEXT,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    country TEXT NOT NULL DEFAULT 'ES',
    updated_at TEXT NOT NULL
  )
`);

db.exec(`
  CREATE TABLE IF NOT EXISTS prices (
    station_id TEXT NOT NULL,
    fuel_type TEXT NOT NULL,
    price REAL NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (station_id, fuel_type),
    FOREIGN KEY (station_id) REFERENCES stations(id)
  )
`);

db.exec(`
  CREATE TABLE IF NOT EXISTS price_history (
    station_id TEXT NOT NULL,
    fuel_type TEXT NOT NULL,
    price REAL NOT NULL,
    recorded_at TEXT NOT NULL
  )
`);

db.exec(`
  CREATE TABLE IF NOT EXISTS country_meta (
    country TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    PRIMARY KEY (country, key)
  )
`);

// --- Idempotent migration for existing DBs ---

function runMigrations() {
  // 1. Add country column to stations if missing
  const stationCols = db.prepare("PRAGMA table_info(stations)").all() as Array<{ name: string }>;
  if (!stationCols.some((c) => c.name === "country")) {
    console.log("[migration] Adding country column to stations...");
    db.exec("ALTER TABLE stations ADD COLUMN country TEXT NOT NULL DEFAULT 'ES'");
  }

  // 2. Prefix existing ES station IDs that lack prefix
  const unprefixedCount = db
    .prepare(
      "SELECT COUNT(*) as cnt FROM stations WHERE id NOT LIKE 'ES_%' AND id NOT LIKE 'GB_%' AND id NOT LIKE 'FR_%' AND id NOT LIKE 'DE_%'"
    )
    .get() as { cnt: number };

  if (unprefixedCount.cnt > 0) {
    console.log(`[migration] Prefixing ${unprefixedCount.cnt} unprefixed station IDs with ES_...`);
    const beforeCount = (db.prepare("SELECT COUNT(*) as cnt FROM stations").get() as { cnt: number }).cnt;

    db.exec("BEGIN TRANSACTION");
    try {
      // Update price_history first (no FK constraint but references station_id)
      db.exec(`
        UPDATE price_history SET station_id = 'ES_' || station_id
        WHERE station_id NOT LIKE 'ES_%' AND station_id NOT LIKE 'GB_%' AND station_id NOT LIKE 'FR_%' AND station_id NOT LIKE 'DE_%'
      `);
      // Update prices (FK to stations.id)
      db.exec(`
        UPDATE prices SET station_id = 'ES_' || station_id
        WHERE station_id NOT LIKE 'ES_%' AND station_id NOT LIKE 'GB_%' AND station_id NOT LIKE 'FR_%' AND station_id NOT LIKE 'DE_%'
      `);
      // Update stations last
      db.exec(`
        UPDATE stations SET id = 'ES_' || id
        WHERE id NOT LIKE 'ES_%' AND id NOT LIKE 'GB_%' AND id NOT LIKE 'FR_%' AND id NOT LIKE 'DE_%'
      `);
      db.exec("COMMIT");
    } catch (e) {
      db.exec("ROLLBACK");
      throw e;
    }

    const afterCount = (
      db.prepare("SELECT COUNT(*) as cnt FROM stations WHERE country='ES'").get() as { cnt: number }
    ).cnt;
    console.log(`[migration] Before: ${beforeCount} stations, After ES: ${afterCount}`);
  }

  // 3. Migrate meta → country_meta if old meta table exists
  const tables = db
    .prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='meta'")
    .all() as Array<{ name: string }>;
  if (tables.length > 0) {
    console.log("[migration] Migrating meta → country_meta...");
    const metaRows = db.prepare("SELECT key, value FROM meta").all() as Array<{ key: string; value: string }>;
    const upsertMeta = db.prepare(
      "INSERT INTO country_meta (country, key, value) VALUES ($country, $key, $value) ON CONFLICT(country, key) DO UPDATE SET value = excluded.value"
    );
    for (const row of metaRows) {
      upsertMeta.run({ $country: "ES", $key: row.key, $value: row.value });
    }
    db.exec("DROP TABLE meta");
    console.log("[migration] meta table migrated and dropped.");
  }
}

runMigrations();

// --- Indexes ---

db.exec("CREATE INDEX IF NOT EXISTS idx_stations_lat ON stations(latitude)");
db.exec("CREATE INDEX IF NOT EXISTS idx_stations_lon ON stations(longitude)");
db.exec("CREATE INDEX IF NOT EXISTS idx_stations_country ON stations(country)");
db.exec("CREATE INDEX IF NOT EXISTS idx_stations_country_lat_lon ON stations(country, latitude, longitude)");
db.exec("CREATE INDEX IF NOT EXISTS idx_prices_fuel ON prices(fuel_type)");
db.exec("CREATE INDEX IF NOT EXISTS idx_prices_station_fuel ON prices(station_id, fuel_type)");
db.exec(
  "CREATE INDEX IF NOT EXISTS idx_history_lookup ON price_history(station_id, fuel_type, recorded_at DESC)"
);
db.exec(
  "CREATE INDEX IF NOT EXISTS idx_history_country ON price_history(station_id, recorded_at DESC)"
);

// --- Prepared statements ---

const upsertStation = db.prepare(`
  INSERT INTO stations (id, name, brand, address, municipality, province, latitude, longitude, country, updated_at)
  VALUES ($id, $name, $brand, $address, $municipality, $province, $latitude, $longitude, $country, $updated_at)
  ON CONFLICT(id) DO UPDATE SET
    name = excluded.name, brand = excluded.brand, address = excluded.address,
    municipality = excluded.municipality, province = excluded.province,
    latitude = excluded.latitude, longitude = excluded.longitude,
    country = excluded.country, updated_at = excluded.updated_at
`);

const upsertPrice = db.prepare(`
  INSERT INTO prices (station_id, fuel_type, price, updated_at)
  VALUES ($station_id, $fuel_type, $price, $updated_at)
  ON CONFLICT(station_id, fuel_type) DO UPDATE SET
    price = excluded.price, updated_at = excluded.updated_at
`);

const insertHistory = db.prepare(`
  INSERT INTO price_history (station_id, fuel_type, price, recorded_at)
  VALUES ($station_id, $fuel_type, $price, $recorded_at)
`);

const setCountryMeta = db.prepare(`
  INSERT INTO country_meta (country, key, value) VALUES ($country, $key, $value)
  ON CONFLICT(country, key) DO UPDATE SET value = excluded.value
`);

const getCountryMeta = db.prepare(
  "SELECT value FROM country_meta WHERE country = $country AND key = $key"
);

// --- Haversine in JS ---

function haversineKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
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

// --- Types ---

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

interface StationDBRow {
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

interface PriceDBRow {
  station_id: string;
  fuel_type: string;
  price: number;
}

// --- Public API ---

export function saveStations(
  country: string,
  stations: Array<{
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
  }>
) {
  const now = new Date().toISOString();

  const transaction = db.transaction(() => {
    for (const s of stations) {
      upsertStation.run({
        $id: s.id,
        $name: s.name,
        $brand: s.brand,
        $address: s.address,
        $municipality: s.municipality,
        $province: s.province,
        $latitude: s.latitude,
        $longitude: s.longitude,
        $country: country,
        $updated_at: s.updatedAt,
      });

      for (const [fuelType, price] of Object.entries(s.prices)) {
        upsertPrice.run({
          $station_id: s.id,
          $fuel_type: fuelType,
          $price: price,
          $updated_at: s.updatedAt,
        });

        insertHistory.run({
          $station_id: s.id,
          $fuel_type: fuelType,
          $price: price,
          $recorded_at: now,
        });
      }
    }

    setCountryMeta.run({ $country: country, $key: "last_fetch", $value: now });
    setCountryMeta.run({
      $country: country,
      $key: "station_count",
      $value: String(stations.length),
    });
  });

  transaction();
}

export function queryStationsNearby(
  lat: number,
  lon: number,
  radiusKm: number,
  country: string = "ES",
  fuelType?: string,
  limit: number = 50
): StationResult[] {
  const degLat = radiusKm / 111.0;
  const degLon = radiusKm / (111.0 * Math.cos((lat * Math.PI) / 180));

  let rows: StationDBRow[];

  if (fuelType) {
    rows = db
      .prepare(
        `
      SELECT DISTINCT s.*
      FROM stations s
      JOIN prices p ON s.id = p.station_id AND p.fuel_type = $fuel_type
      WHERE s.country = $country
        AND s.latitude BETWEEN $min_lat AND $max_lat
        AND s.longitude BETWEEN $min_lon AND $max_lon
    `
      )
      .all({
        $country: country,
        $fuel_type: fuelType,
        $min_lat: lat - degLat,
        $max_lat: lat + degLat,
        $min_lon: lon - degLon,
        $max_lon: lon + degLon,
      }) as StationDBRow[];
  } else {
    rows = db
      .prepare(
        `
      SELECT * FROM stations
      WHERE country = $country
        AND latitude BETWEEN $min_lat AND $max_lat
        AND longitude BETWEEN $min_lon AND $max_lon
    `
      )
      .all({
        $country: country,
        $min_lat: lat - degLat,
        $max_lat: lat + degLat,
        $min_lon: lon - degLon,
        $max_lon: lon + degLon,
      }) as StationDBRow[];
  }

  const withDistance = rows
    .map((s) => ({
      ...s,
      distance_km: haversineKm(lat, lon, s.latitude, s.longitude),
    }))
    .filter((s) => s.distance_km <= radiusKm)
    .sort((a, b) => a.distance_km - b.distance_km)
    .slice(0, limit);

  const stationIds = withDistance.map((s) => s.id);
  if (stationIds.length === 0) return [];

  const placeholders = stationIds.map(() => "?").join(",");
  const allPrices = db
    .prepare(
      `SELECT station_id, fuel_type, price FROM prices WHERE station_id IN (${placeholders})`
    )
    .all(...stationIds) as PriceDBRow[];

  const priceMap = new Map<string, Record<string, number>>();
  for (const p of allPrices) {
    if (!priceMap.has(p.station_id)) priceMap.set(p.station_id, {});
    priceMap.get(p.station_id)![p.fuel_type] = p.price;
  }

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

export function queryCheapest(
  lat: number,
  lon: number,
  radiusKm: number,
  fuelType: string,
  country: string = "ES"
): StationResult | null {
  const results = queryStationsNearby(lat, lon, radiusKm, country, fuelType, 500);
  if (results.length === 0) return null;

  return results.reduce((cheapest, s) => {
    const sPrice = s.prices[fuelType] ?? Infinity;
    const cPrice = cheapest.prices[fuelType] ?? Infinity;
    return sPrice < cPrice ? s : cheapest;
  });
}

export function queryAveragePrice(
  lat: number,
  lon: number,
  radiusKm: number,
  fuelType: string,
  country: string = "ES"
): { average: number; count: number } | null {
  const results = queryStationsNearby(lat, lon, radiusKm, country, fuelType, 500);
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

export function queryStationDetail(stationId: string): StationResult | null {
  // Compat: if no country prefix, assume ES
  let resolvedId = stationId;
  if (!/^(ES|GB|FR|DE)_/.test(stationId)) {
    console.warn(`[compat] Station ID without country prefix: ${stationId}, assuming ES_`);
    resolvedId = `ES_${stationId}`;
  }

  const station = db
    .prepare("SELECT * FROM stations WHERE id = $id")
    .get({ $id: resolvedId }) as StationDBRow | null;

  if (!station) return null;

  const prices = db
    .prepare("SELECT fuel_type, price FROM prices WHERE station_id = $id")
    .all({ $id: resolvedId }) as PriceDBRow[];

  const priceMap: Record<string, number> = {};
  for (const p of prices) priceMap[p.fuel_type] = p.price;

  return {
    ...station,
    distance_km: 0,
    prices: priceMap,
  };
}

export function queryPriceHistory(
  stationId: string,
  days: number = 30,
  limit: number = 1000
): Array<{ recorded_at: string; fuel_type: string; price: number }> {
  let resolvedId = stationId;
  if (!/^(ES|GB|FR|DE)_/.test(stationId)) {
    resolvedId = `ES_${stationId}`;
  }

  const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

  return db
    .prepare(
      `SELECT recorded_at, fuel_type, price FROM price_history
       WHERE station_id = $id AND recorded_at >= $cutoff
       ORDER BY recorded_at DESC
       LIMIT $limit`
    )
    .all({ $id: resolvedId, $cutoff: cutoff, $limit: limit }) as Array<{
    recorded_at: string;
    fuel_type: string;
    price: number;
  }>;
}

export function queryCountryStats(): Array<{
  country: string;
  station_count: number;
  last_fetched_at: string | null;
}> {
  const countries = db
    .prepare("SELECT DISTINCT country FROM stations ORDER BY country")
    .all() as Array<{ country: string }>;

  return countries.map((c) => {
    const count = (
      db
        .prepare("SELECT COUNT(*) as cnt FROM stations WHERE country = $country")
        .get({ $country: c.country }) as { cnt: number }
    ).cnt;

    const meta = db
      .prepare("SELECT value FROM country_meta WHERE country = $country AND key = 'last_fetch'")
      .get({ $country: c.country }) as { value: string } | null;

    return {
      country: c.country,
      station_count: count,
      last_fetched_at: meta?.value ?? null,
    };
  });
}

export function getCountryMetaValue(country: string, key: string): string | null {
  const row = getCountryMeta.get({ $country: country, $key: key }) as { value: string } | null;
  return row?.value ?? null;
}

// Legacy compat — reads from ES by default
export function getMetaValue(key: string): string | null {
  return getCountryMetaValue("ES", key);
}

export default db;
