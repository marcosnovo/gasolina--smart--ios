-- Gasolina Smart D1 schema
-- Mirrors the Bun/SQLite backend, adapted for D1.
-- D1 supports SQLite syntax but does not support PRAGMA or FOREIGN KEY enforcement.

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
);

CREATE TABLE IF NOT EXISTS prices (
  station_id TEXT NOT NULL,
  fuel_type TEXT NOT NULL,
  price REAL NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (station_id, fuel_type)
);

CREATE TABLE IF NOT EXISTS price_history (
  station_id TEXT NOT NULL,
  fuel_type TEXT NOT NULL,
  price REAL NOT NULL,
  recorded_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS country_meta (
  country TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  PRIMARY KEY (country, key)
);

CREATE INDEX IF NOT EXISTS idx_stations_country ON stations(country);
CREATE INDEX IF NOT EXISTS idx_stations_country_lat_lon ON stations(country, latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_prices_station_fuel ON prices(station_id, fuel_type);
CREATE INDEX IF NOT EXISTS idx_history_lookup ON price_history(station_id, fuel_type, recorded_at DESC);

-- EV charging stations (sourced from OpenChargeMap).
-- Connectors are denormalised into a JSON blob; the iOS client decodes them
-- straight into ChargingConnection structs.
CREATE TABLE IF NOT EXISTS charging_stations (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  operator_name TEXT,
  address TEXT,
  municipality TEXT,
  province TEXT,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  country TEXT NOT NULL,
  number_of_points INTEGER NOT NULL DEFAULT 1,
  is_operational INTEGER NOT NULL DEFAULT 1,
  usage_cost TEXT,
  max_power_kw REAL,
  connectors_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_charging_country ON charging_stations(country);
CREATE INDEX IF NOT EXISTS idx_charging_country_lat_lon ON charging_stations(country, latitude, longitude);
