import { Hono } from "hono";
import { cors } from "hono/cors";
import {
  queryStationsNearby,
  queryAllStations,
  queryAllChargingStations,
  queryCheapest,
  queryAveragePrice,
  queryStationDetail,
  queryPriceHistory,
  queryCountryStats,
  getCountryMetaValue,
  setCountryMetaValue,
} from "./database";
import { fetchOpenChargeMap, shouldFetchChargingStations } from "./fetchers/openchargemap";
import { COUNTRY_INFO, SUPPORTED_COUNTRIES } from "./countries";
import { fetchSpain, shouldFetchSpain } from "./fetchers/spain";
import { fetchFrance, shouldFetchFrance } from "./fetchers/france";
import { fetchUK } from "./fetchers/uk";
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
  OPENCHARGEMAP_API_KEY?: string;
}

const app = new Hono<{ Bindings: Env }>();

app.use("/*", cors());

// --- Health ---

app.get("/health", (c) =>
  c.json({ status: "ok", timestamp: new Date().toISOString() })
);

// Railway fallback base — gov.uk filters Cloudflare's outbound IPs so
// UK fuel data lives there instead of in the Worker's D1.
const RAILWAY_FALLBACK_URL = "https://gasolina-smart-ios-production.up.railway.app";

interface RailwayMetaResponse {
  station_count?: number;
  last_fetch?: string | null;
}

async function fetchUKFuelStatsFromRailway(): Promise<RailwayMetaResponse | null> {
  try {
    const resp = await fetch(`${RAILWAY_FALLBACK_URL}/api/meta?country=GB`, {
      signal: AbortSignal.timeout(3000),
    });
    if (!resp.ok) return null;
    return (await resp.json()) as RailwayMetaResponse;
  } catch {
    return null;
  }
}

app.get("/api/health", async (c) => {
  const stats = await queryCountryStats(c.env.DB);
  const statsMap = new Map(stats.map((s) => [s.country, s]));

  const countries: Record<string, unknown> = {};
  for (const code of SUPPORTED_COUNTRIES) {
    const stat = statsMap.get(code);
    const lastError = await getCountryMetaValue(c.env.DB, code, "last_error");
    let lastFetch = stat?.last_fetched_at ?? null;
    let stationsCount = stat?.station_count ?? 0;
    const chargingCount = stat?.charging_count ?? 0;
    const chargingLastFetch = stat?.charging_last_fetched_at ?? null;

    // UK fuel data lives on the Railway fallback because gov.uk filters
    // Cloudflare's outbound IPs. Bridge the count + last-fetch over so
    // /api/health gives a complete picture of every country, even
    // though this Worker doesn't store UK fuel rows itself.
    let delegated: string | undefined;
    if (code === "GB") {
      const railway = await fetchUKFuelStatsFromRailway();
      if (railway) {
        stationsCount = railway.station_count ?? stationsCount;
        lastFetch = railway.last_fetch ?? lastFetch;
        delegated = "railway";
      }
    }

    let status: string;
    let reason: string | undefined;

    if (code === "GB" && delegated) {
      // We deliberately don't run the UK fetcher on this Worker, so any
      // stale `last_error` from before that change is noise. Status
      // reflects whether the Railway fallback has data.
      status = stationsCount > 0 ? "delegated" : "waiting";
    } else if (lastError && lastError.includes("PAUSED:")) {
      status = "paused";
      reason = lastError.replace(/^.*PAUSED:\s*/, "");
    } else if (lastError) {
      status = "error";
      reason = lastError;
    } else if (stationsCount > 0 || chargingCount > 0) {
      status = "ok";
    } else {
      status = "waiting";
    }

    countries[code] = {
      status,
      stationsCount,
      chargingCount,
      lastFetch,
      chargingLastFetch,
      ...(delegated ? { delegatedTo: delegated } : {}),
      ...(reason ? { reason } : {}),
    };
  }

  return c.json({ ok: true, countries });
});

// --- Metadata ---

app.get("/api/meta", async (c) => {
  const country = c.req.query("country") || "ES";
  const [lastFetch, stationCount, chargingLastFetch, chargingCount] = await Promise.all([
    getCountryMetaValue(c.env.DB, country, "last_fetch"),
    getCountryMetaValue(c.env.DB, country, "station_count"),
    getCountryMetaValue(c.env.DB, country, "charging_last_fetch"),
    getCountryMetaValue(c.env.DB, country, "charging_station_count"),
  ]);
  return c.json({
    last_fetch: lastFetch,
    station_count: parseInt(stationCount || "0"),
    charging_last_fetch: chargingLastFetch,
    charging_station_count: parseInt(chargingCount || "0"),
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

// --- EV charging stations (full snapshot) ---
app.get("/api/charging/all", async (c) => {
  const country = c.req.query("country") || "ES";
  const stations = await queryAllChargingStations(c.env.DB, country);
  const lastUpdated = await getCountryMetaValue(c.env.DB, country, "charging_last_fetch");

  return c.json({
    stations,
    count: stations.length,
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

// --- Manual EV charging fetch trigger ---

app.post("/api/fetch-charging", async (c) => {
  const country = c.req.query("country") || "ES";
  try {
    const result = await fetchOpenChargeMap(c.env.DB, country, c.env.OPENCHARGEMAP_API_KEY);
    await setCountryMetaValue(c.env.DB, country, "charging_last_error", "");
    return c.json({ success: true, country, ...result });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    await setCountryMetaValue(
      c.env.DB,
      country,
      "charging_last_error",
      `${new Date().toISOString()} — ${message}`
    );
    return c.json({ success: false, country, error: message }, 500);
  }
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
  // Daily Italy fetch + EV charging refresh across all countries
  // (OpenChargeMap data changes slowly — once a day is plenty and
  // keeps us safely under the free-tier API quota.)
  if (event.cron === "0 6 * * *") {
    console.log("[cron] Daily IT + EV charging trigger");
    await runFetcher(env.DB, "IT", () => fetchItaly(env.DB));

    for (const country of ["ES", "FR", "GB", "DE", "IT", "US"]) {
      if (await shouldFetchChargingStations(env.DB, country, 60 * 12)) {
        await runFetcher(env.DB, country, () =>
          fetchOpenChargeMap(env.DB, country, env.OPENCHARGEMAP_API_KEY)
        );
      }
    }
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
  // UK is served exclusively from the Railway fallback backend: gov.uk's
  // edge filters Cloudflare Workers' outbound IPs (HTTP 525 SSL handshake
  // failed). The iOS client routes UK requests to Railway directly via
  // BackendAPIService.base(forCountry: .uk), so populating UK in D1 from
  // this Worker is both impossible and pointless — it would just spam
  // the cron logs with 31 errors every 15 min.
  //
  // The manual /api/fetch?country=GB endpoint is intentionally kept
  // active in case Cloudflare ever resolves the gov.uk relationship.
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
