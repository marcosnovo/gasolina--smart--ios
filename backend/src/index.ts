import { Hono } from "hono";
import { cors } from "hono/cors";
import { serve } from "bun";
import {
  queryStationsNearby,
  queryCheapest,
  queryAveragePrice,
  queryStationDetail,
  getCountryMetaValue,
} from "./database";
import { fetchFromMinisterio, getLastFetchTime, shouldFetch } from "./fetcher";

const app = new Hono();

const FETCH_INTERVAL = parseInt(process.env.FETCH_INTERVAL_MINUTES || "15");
const PORT = parseInt(process.env.PORT || "3000");

app.use("/*", cors());

// --- Health ---

app.get("/health", (c) => c.json({ status: "ok", timestamp: new Date().toISOString() }));

// --- Metadata ---

app.get("/api/meta", (c) => {
  const country = c.req.query("country") || "ES";
  return c.json({
    last_fetch: getCountryMetaValue(country, "last_fetch"),
    station_count: parseInt(getCountryMetaValue(country, "station_count") || "0"),
    fetch_interval_minutes: FETCH_INTERVAL,
  });
});

// --- Stations nearby ---

app.get("/api/stations", (c) => {
  const lat = parseFloat(c.req.query("lat") || "");
  const lon = parseFloat(c.req.query("lon") || "");
  const radius = parseFloat(c.req.query("radius") || "10");
  const fuel = c.req.query("fuel");
  const limit = parseInt(c.req.query("limit") || "50");
  const country = c.req.query("country") || "ES";

  if (isNaN(lat) || isNaN(lon)) {
    return c.json({ error: "lat and lon are required" }, 400);
  }

  const stations = queryStationsNearby(lat, lon, radius, country, fuel, limit);
  const avg = fuel ? queryAveragePrice(lat, lon, radius, fuel, country) : null;

  return c.json({
    stations,
    count: stations.length,
    average_price: avg?.average ?? null,
    zone_count: avg?.count ?? null,
    last_updated: getCountryMetaValue(country, "last_fetch"),
  });
});

// --- Cheapest ---

app.get("/api/stations/cheapest", (c) => {
  const lat = parseFloat(c.req.query("lat") || "");
  const lon = parseFloat(c.req.query("lon") || "");
  const radius = parseFloat(c.req.query("radius") || "10");
  const fuel = c.req.query("fuel") || "gasolina95";
  const country = c.req.query("country") || "ES";

  if (isNaN(lat) || isNaN(lon)) {
    return c.json({ error: "lat and lon are required" }, 400);
  }

  const station = queryCheapest(lat, lon, radius, fuel, country);
  const avg = queryAveragePrice(lat, lon, radius, fuel, country);

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

app.get("/api/stations/:id", (c) => {
  const id = c.req.param("id");
  const station = queryStationDetail(id);

  if (!station) {
    return c.json({ error: "Station not found" }, 404);
  }

  return c.json({ station });
});

// --- Manual fetch trigger ---

app.post("/api/fetch", async (c) => {
  try {
    const result = await fetchFromMinisterio();
    return c.json({ success: true, ...result });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return c.json({ success: false, error: message }, 500);
  }
});

// --- Cron: periodic fetch ---

async function startCron() {
  console.log(`[cron] Fetch interval: every ${FETCH_INTERVAL} minutes`);

  if (shouldFetch(FETCH_INTERVAL)) {
    console.log("[cron] No recent data, fetching now...");
    try {
      await fetchFromMinisterio();
    } catch (e) {
      console.error("[cron] Initial fetch failed:", e);
    }
  } else {
    console.log(`[cron] Data is fresh (last: ${getLastFetchTime()})`);
  }

  setInterval(
    async () => {
      console.log("[cron] Scheduled fetch starting...");
      try {
        await fetchFromMinisterio();
      } catch (e) {
        console.error("[cron] Fetch failed:", e);
      }
    },
    FETCH_INTERVAL * 60 * 1000
  );
}

// --- Start ---

startCron();

console.log(`[server] GasolinaSmart API running on port ${PORT}`);

export default {
  port: PORT,
  fetch: app.fetch,
};
