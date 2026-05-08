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
  CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
`);

db.exec("CREATE INDEX IF NOT EXISTS idx_stations_lat ON stations(latitude)");
db.exec("CREATE INDEX IF NOT EXISTS idx_stations_lon ON stations(longitude)");
db.exec("CREATE INDEX IF NOT EXISTS idx_prices_fuel ON prices(fuel_type)");
db.exec(
  "CREATE INDEX IF NOT EXISTS idx_history_lookup ON price_history(station_id, fuel_type, recorded_at)"
);

// --- Prepared statements ---

const upsertStation = db.prepare(`
  INSERT INTO stations (id, name, brand, address, municipality, province, latitude, longitude, updated_at)
  VALUES ($id, $name, $brand, $address, $municipality, $province, $latitude, $longitude, $updated_at)
  ON CONFLICT(id) DO UPDATE SET
    name = excluded.name, brand = excluded.brand, address = excluded.address,
    municipality = excluded.municipality, province = excluded.province,
    latitude = excluded.latitude, longitude = excluded.longitude,
    updated_at = excluded.updated_at
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

const setMeta = db.prepare(`
  INSERT INTO meta (key, value) VALUES ($key, $value)
  ON CONFLICT(key) DO UPDATE SET value = excluded.value
`);

const getMeta = db.prepare("SELECT value FROM meta WHERE key = $key");

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
  updated_at: string;
}

interface PriceDBRow {
  station_id: string;
  fuel_type: string;
  price: number;
}

// --- Public API ---

export function saveStations(
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

    setMeta.run({ $key: "last_fetch", $value: now });
    setMeta.run({ $key: "station_count", $value: String(stations.length) });
  });

  transaction();
}

export function queryStationsNearby(
  lat: number,
  lon: number,
  radiusKm: number,
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
      WHERE s.latitude BETWEEN $min_lat AND $max_lat
        AND s.longitude BETWEEN $min_lon AND $max_lon
    `
      )
      .all({
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
      WHERE latitude BETWEEN $min_lat AND $max_lat
        AND longitude BETWEEN $min_lon AND $max_lon
    `
      )
      .all({
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
    updated_at: s.updated_at,
    distance_km: Math.round(s.distance_km * 100) / 100,
    prices: priceMap.get(s.id) || {},
  }));
}

export function queryCheapest(
  lat: number,
  lon: number,
  radiusKm: number,
  fuelType: string
): StationResult | null {
  const results = queryStationsNearby(lat, lon, radiusKm, fuelType, 500);
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
  fuelType: string
): { average: number; count: number } | null {
  const results = queryStationsNearby(lat, lon, radiusKm, fuelType, 500);
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
  const station = db
    .prepare("SELECT * FROM stations WHERE id = $id")
    .get({ $id: stationId }) as StationDBRow | null;

  if (!station) return null;

  const prices = db
    .prepare("SELECT fuel_type, price FROM prices WHERE station_id = $id")
    .all({ $id: stationId }) as PriceDBRow[];

  const priceMap: Record<string, number> = {};
  for (const p of prices) priceMap[p.fuel_type] = p.price;

  return {
    ...station,
    distance_km: 0,
    prices: priceMap,
  };
}

export function getMetaValue(key: string): string | null {
  const row = getMeta.get({ $key: key }) as { value: string } | null;
  return row?.value ?? null;
}

export default db;
