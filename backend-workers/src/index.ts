import { Hono } from "hono";
import { cors } from "hono/cors";
import {
  queryStationsNearby,
  queryAllStations,
  queryCheapest,
  queryAveragePrice,
  queryStationDetail,
  queryPriceHistory,
  queryCountryStats,
  getCountryMetaValue,
  setCountryMetaValue,
} from "./database";
import { COUNTRY_INFO, SUPPORTED_COUNTRIES } from "./countries";
import { fetchSpain, shouldFetchSpain } from "./fetchers/spain";
import { fetchFrance, shouldFetchFrance } from "./fetchers/france";
import { fetchUK, shouldFetchUK } from "./fetchers/uk";
import { fetchGermany, shouldFetchGermany } from "./fetchers/germany";
import { fetchItaly } from "./fetchers/italy";

const FETCH_INTERVALS = {
  ES: 15,
  FR: 30,
  GB: 15,
  DE: 15,
} as const;

export interface Env {
  DB: D1Database;
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

// --- All stations of a country (full snapshot) ---
//
// Returns every station of a country in one shot — the iOS client fetches
// this once on country switch and runs all subsequent searches locally,
// so the experience stays snappy and we avoid hammering the worker.
app.get("/api/stations/all", async (c) => {
  const country = c.req.query("country") || "ES";

  const stations = await queryAllStations(c.env.DB, country);
  const lastUpdated = await getCountryMetaValue(c.env.DB, country, "last_fetch");

  return c.json({
    stations,
    count: stations.length,
    average_price: null,
    zone_count: null,
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
      case "GB":
        result = await fetchUK(c.env.DB);
        break;
      case "DE":
        result = await fetchGermany(c.env.DB, c.env.TANKERKOENIG_API_KEY);
        break;
      case "IT":
        result = await fetchItaly(c.env.DB);
        break;
      default:
        return c.json({ success: false, error: `Unknown country: ${country}` }, 400);
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

// --- Scheduled handler (Cron Triggers) ---

async function runFetcher(
  db: D1Database,
  country: string,
  fn: () => Promise<unknown>
): Promise<void> {
  try {
    await fn();
    await setCountryMetaValue(db, country, "last_error", "");
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error(`[cron:${country}] Fetch failed: ${message}`);
    await setCountryMetaValue(
      db,
      country,
      "last_error",
      `${new Date().toISOString()} — ${message}`
    );
  }
}

async function runScheduled(event: ScheduledController, env: Env): Promise<void> {
  // Daily Italy fetch
  if (event.cron === "0 6 * * *") {
    console.log("[cron] Daily IT trigger");
    await runFetcher(env.DB, "IT", () => fetchItaly(env.DB));
    return;
  }

  // Every-15-min dispatch — each country checks its own interval
  console.log(`[cron] 15-min trigger at ${new Date(event.scheduledTime).toISOString()}`);

  if (await shouldFetchSpain(env.DB, FETCH_INTERVALS.ES)) {
    await runFetcher(env.DB, "ES", () => fetchSpain(env.DB));
  }
  if (await shouldFetchFrance(env.DB, FETCH_INTERVALS.FR)) {
    await runFetcher(env.DB, "FR", () => fetchFrance(env.DB));
  }
  if (await shouldFetchUK(env.DB, FETCH_INTERVALS.GB)) {
    await runFetcher(env.DB, "GB", () => fetchUK(env.DB));
  }
  if (await shouldFetchGermany(env.DB, FETCH_INTERVALS.DE)) {
    await runFetcher(env.DB, "DE", () => fetchGermany(env.DB, env.TANKERKOENIG_API_KEY));
  }
}

export default {
  fetch: app.fetch,
  scheduled(event: ScheduledController, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(runScheduled(event, env));
  },
};
