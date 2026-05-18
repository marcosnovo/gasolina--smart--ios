import { Hono } from "hono";
import { cors } from "hono/cors";
import {
  queryStationsNearby,
  queryCheapest,
  queryAveragePrice,
  queryStationDetail,
  queryPriceHistory,
  queryCountryStats,
  getCountryMetaValue,
  setCountryMetaValue,
} from "./database";
import { COUNTRY_INFO, SUPPORTED_COUNTRIES } from "./countries";
import { fetchSpain } from "./fetchers/spain";
import { fetchFrance } from "./fetchers/france";

export interface Env {
  DB: D1Database;
  SNAPSHOTS: R2Bucket;
  TANKERKOENIG_API_KEY?: string;
}

const app = new Hono<{ Bindings: Env }>();

app.use("/*", cors());

// --- Health ---

app.get("/health", (c) =>
  c.json({ status: "ok", timestamp: new Date().toISOString() })
);

app.get("/api/health", async (c) => {
  const stats = await queryCountryStats(c.env.DB);
  const statsMap = new Map(stats.map((s) => [s.country, s]));

  const countries: Record<string, unknown> = {};
  for (const code of SUPPORTED_COUNTRIES) {
    const stat = statsMap.get(code);
    const lastError = await getCountryMetaValue(c.env.DB, code, "last_error");
    const lastFetch = stat?.last_fetched_at ?? null;
    const stationsCount = stat?.station_count ?? 0;

    let status: string;
    let reason: string | undefined;

    if (lastError && lastError.includes("PAUSED:")) {
      status = "paused";
      reason = lastError.replace(/^.*PAUSED:\s*/, "");
    } else if (lastError) {
      status = "error";
      reason = lastError;
    } else if (stationsCount > 0) {
      status = "ok";
    } else {
      status = "waiting";
    }

    countries[code] = {
      status,
      stationsCount,
      lastFetch,
      ...(reason ? { reason } : {}),
    };
  }

  return c.json({ ok: true, countries });
});

// --- Metadata ---

app.get("/api/meta", async (c) => {
  const country = c.req.query("country") || "ES";
  const lastFetch = await getCountryMetaValue(c.env.DB, country, "last_fetch");
  const stationCount = await getCountryMetaValue(c.env.DB, country, "station_count");
  return c.json({
    last_fetch: lastFetch,
    station_count: parseInt(stationCount || "0"),
  });
});

// --- Stations nearby ---

app.get("/api/stations", async (c) => {
  const lat = parseFloat(c.req.query("lat") || "");
  const lon = parseFloat(c.req.query("lon") || "");
  const radius = parseFloat(c.req.query("radius") || "10");
  const fuel = c.req.query("fuel");
  const limit = parseInt(c.req.query("limit") || "50");
  const country = c.req.query("country") || "ES";

  if (isNaN(lat) || isNaN(lon)) {
    return c.json({ error: "lat and lon are required" }, 400);
  }

  const stations = await queryStationsNearby(c.env.DB, lat, lon, radius, country, fuel, limit);
  const avg = fuel ? await queryAveragePrice(c.env.DB, lat, lon, radius, fuel, country) : null;
  const lastUpdated = await getCountryMetaValue(c.env.DB, country, "last_fetch");

  return c.json({
    stations,
    count: stations.length,
    average_price: avg?.average ?? null,
    zone_count: avg?.count ?? null,
    last_updated: lastUpdated,
  });
});

// --- Cheapest ---

app.get("/api/stations/cheapest", async (c) => {
  const lat = parseFloat(c.req.query("lat") || "");
  const lon = parseFloat(c.req.query("lon") || "");
  const radius = parseFloat(c.req.query("radius") || "10");
  const fuel = c.req.query("fuel") || "gasolina95";
  const country = c.req.query("country") || "ES";

  if (isNaN(lat) || isNaN(lon)) {
    return c.json({ error: "lat and lon are required" }, 400);
  }

  const station = await queryCheapest(c.env.DB, lat, lon, radius, fuel, country);
  const avg = await queryAveragePrice(c.env.DB, lat, lon, radius, fuel, country);

  if (!station) {
    return c.json({ station: null, average_price: null });
  }

  return c.json({
    station,
    average_price: avg?.average ?? null,
    zone_count: avg?.count ?? null,
  });
});

// --- Station detail ---

app.get("/api/stations/:id", async (c) => {
  const id = c.req.param("id");
  const station = await queryStationDetail(c.env.DB, id);

  if (!station) {
    return c.json({ error: "Station not found" }, 404);
  }

  return c.json({ station });
});

// --- Countries ---

app.get("/api/countries", async (c) => {
  const stats = await queryCountryStats(c.env.DB);
  const statsMap = new Map(stats.map((s) => [s.country, s]));

  const countries = await Promise.all(
    Object.entries(COUNTRY_INFO).map(async ([code, info]) => {
      const stat = statsMap.get(code);
      const lastError = await getCountryMetaValue(c.env.DB, code, "last_error");
      return {
        code,
        ...info,
        stationsCount: stat?.station_count ?? 0,
        lastFetchedAt: stat?.last_fetched_at ?? null,
        lastError,
      };
    })
  );

  return c.json(countries);
});

// --- Price history ---

app.get("/api/history/:stationId", async (c) => {
  const stationId = c.req.param("stationId");
  const days = parseInt(c.req.query("days") || "30");

  const history = await queryPriceHistory(c.env.DB, stationId, days);

  return c.json(history);
});

// --- Manual fetch trigger ---

app.post("/api/fetch", async (c) => {
  const country = c.req.query("country") || "ES";

  try {
    let result: { count: number; duration: number };
    switch (country) {
      case "ES":
        result = await fetchSpain(c.env.DB);
        break;
      case "FR":
        result = await fetchFrance(c.env.DB);
        break;
      default:
        return c.json({ success: false, error: `Country ${country} not yet ported` }, 400);
    }

    await setCountryMetaValue(c.env.DB, country, "last_error", "");
    return c.json({ success: true, country, ...result });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    await setCountryMetaValue(
      c.env.DB,
      country,
      "last_error",
      `${new Date().toISOString()} — ${message}`
    );
    return c.json({ success: false, country, error: message }, 500);
  }
});

export default app;
