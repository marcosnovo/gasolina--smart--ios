import { Hono } from "hono";
import { cors } from "hono/cors";
import { serve } from "bun";
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
import { fetchFromMinisterio, getLastFetchTime, shouldFetch } from "./fetcher";
import { fetchUK, shouldFetchUK } from "./fetchers/uk";
import { fetchFrance, shouldFetchFrance } from "./fetchers/france";
import { fetchGermany, shouldFetchGermany } from "./fetchers/germany";

const app = new Hono();

const FETCH_INTERVAL = parseInt(process.env.FETCH_INTERVAL_MINUTES || "15");
const UK_FETCH_INTERVAL = parseInt(process.env.UK_FETCH_INTERVAL_MINUTES || "15");
const FR_FETCH_INTERVAL = parseInt(process.env.FR_FETCH_INTERVAL_MINUTES || "30");
const DE_FETCH_INTERVAL = parseInt(process.env.DE_FETCH_INTERVAL_MINUTES || "15");
const PORT = parseInt(process.env.PORT || "3000");

app.use("/*", cors());

// --- Health ---

app.get("/health", (c) => c.json({ status: "ok", timestamp: new Date().toISOString() }));

app.get("/api/health", (c) => {
  const stats = queryCountryStats();
  const statsMap = new Map(stats.map((s) => [s.country, s]));

  const countries: Record<string, unknown> = {};
  for (const code of ["ES", "GB", "FR", "DE"]) {
    const stat = statsMap.get(code);
    const lastError = getCountryMetaValue(code, "last_error") || null;
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

// --- Countries ---

const COUNTRY_INFO: Record<
  string,
  {
    displayName: string;
    currency: string;
    currencySymbol: string;
    supportedFuels: string[];
    dataFreshness: string;
    attribution: { text: string; url: string; license: string };
  }
> = {
  ES: {
    displayName: "España",
    currency: "EUR",
    currencySymbol: "€",
    supportedFuels: ["gasolina95", "gasolina98", "dieselA", "dieselPremium", "glp"],
    dataFreshness: "within1hour",
    attribution: {
      text: "Ministerio para la Transición Ecológica y el Reto Demográfico",
      url: "https://geoportalgasolineras.es",
      license: "Reutilización libre",
    },
  },
  GB: {
    displayName: "United Kingdom",
    currency: "GBP",
    currencySymbol: "£",
    supportedFuels: ["e10", "e5", "gasolina98", "dieselA", "dieselPremium"],
    dataFreshness: "within30min",
    attribution: {
      text: "Crown copyright. Source: Fuel Finder, operated by VE3 Global Ltd under the Motor Fuel Price (Open Data) Regulations 2025",
      url: "https://developer.fuel-finder.service.gov.uk",
      license: "Open Government Licence v3.0",
    },
  },
  FR: {
    displayName: "France",
    currency: "EUR",
    currencySymbol: "€",
    supportedFuels: ["e10", "e5", "gasolina98", "dieselA", "e85", "glp"],
    dataFreshness: "within1hour",
    attribution: {
      text: "Licence Ouverte / Open Licence. Source: data.economie.gouv.fr",
      url: "https://data.economie.gouv.fr",
      license: "Licence Ouverte v2.0",
    },
  },
  DE: {
    displayName: "Deutschland",
    currency: "EUR",
    currencySymbol: "€",
    supportedFuels: ["e5", "e10", "dieselA"],
    dataFreshness: "realtime",
    attribution: {
      text: "Spritpreis-Daten von Tankerkönig, lizenziert unter CC BY 4.0",
      url: "https://creativecommons.tankerkoenig.de",
      license: "CC BY 4.0",
    },
  },
};

app.get("/api/countries", (c) => {
  const stats = queryCountryStats();
  const statsMap = new Map(stats.map((s) => [s.country, s]));

  const countries = Object.entries(COUNTRY_INFO).map(([code, info]) => {
    const stat = statsMap.get(code);
    return {
      code,
      ...info,
      stationsCount: stat?.station_count ?? 0,
      lastFetchedAt: stat?.last_fetched_at ?? null,
      lastError: getCountryMetaValue(code, "last_error"),
    };
  });

  return c.json(countries);
});

// --- Price history ---

app.get("/api/history/:stationId", (c) => {
  const stationId = c.req.param("stationId");
  const days = parseInt(c.req.query("days") || "30");

  const history = queryPriceHistory(stationId, days);

  return c.json(history);
});

// --- Manual fetch trigger ---

app.post("/api/fetch", async (c) => {
  const country = c.req.query("country") || "ES";
  try {
    let result: { count: number; duration: number };
    switch (country) {
      case "ES":
        result = await fetchFromMinisterio();
        break;
      case "GB":
        result = await fetchUK();
        break;
      case "FR":
        result = await fetchFrance();
        break;
      case "DE":
        result = await fetchGermany();
        break;
      default:
        return c.json({ success: false, error: `Unknown country: ${country}` }, 400);
    }
    return c.json({ success: true, country, ...result });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    const stack = error instanceof Error ? error.stack : undefined;
    return c.json({ success: false, country, error: message, stack }, 500);
  }
});

// --- Diagnostic: test external APIs ---

app.get("/api/debug/test-apis", async (c) => {
  const results: Record<string, unknown> = {};

  async function probe(label: string, url: string, headers?: Record<string, string>) {
    try {
      const res = await fetch(url, { headers: headers || {} });
      const text = await res.text();
      return {
        status: res.status,
        contentType: res.headers.get("content-type"),
        bodyPreview: text.slice(0, 200),
        bodyLength: text.length,
      };
    } catch (e) {
      return { error: String(e) };
    }
  }

  // --- France: 3 User-Agent variants ---
  const frBase = "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/records?limit=1";

  results.france_A_default = await probe("FR default", frBase);
  results.france_B_browser = await probe("FR browser", frBase, {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    Accept: "application/json",
  });
  results.france_C_polite = await probe("FR polite", frBase, {
    "User-Agent": "GasolinaSmart/1.0 (+https://gasolina-smart.app; contact@gasolina-smart.app)",
    Accept: "application/json",
  });

  // --- UK: connectivity checks ---
  results.uk_github = await probe("github", "https://api.github.com/zen");
  results.uk_govuk = await probe("gov.uk", "https://www.gov.uk/");
  results.uk_devportal = await probe("fuel-finder portal", "https://developer.fuel-finder.service.gov.uk/");
  results.uk_api = await probe("fuel-finder API", "https://developer.fuel-finder.service.gov.uk/public-api/stations/nearby?latitude=51.5&longitude=-0.12&radius=5", {
    "User-Agent": "GasolinaSmart-Backend/1.0",
    Accept: "application/json",
  });

  // --- France: /exports/json with 3 UA variants ---
  const frExport = "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/exports/json?limit=1";
  results.france_export_default = await probe("FR export default", frExport);
  results.france_export_browser = await probe("FR export browser", frExport, {
    "User-Agent": "Mozilla/5.0 (compatible)",
    Accept: "application/json",
  });
  results.france_export_polite = await probe("FR export polite", frExport, {
    "User-Agent": "GasolinaSmart/1.0 (+contact@gasolina-smart.app)",
    Accept: "application/json",
  });

  // --- Germany: demo key ---
  results.germany_demo = await probe("tankerkoenig demo",
    "https://creativecommons.tankerkoenig.de/json/list.php?lat=52.52&lng=13.40&rad=5&type=all&apikey=00000000-0000-0000-0000-000000000002"
  );

  return c.json(results);
});

// --- Cron: periodic fetch with error isolation ---

async function runFetcher(country: string, fn: () => Promise<unknown>) {
  try {
    await fn();
    setCountryMetaValue(country, "last_error", "");
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error(`[cron:${country}] Fetch failed: ${message}`);
    setCountryMetaValue(country, "last_error", `${new Date().toISOString()} — ${message}`);
  }
}

async function startCron() {
  console.log(`[cron] ES:${FETCH_INTERVAL}min, GB:${UK_FETCH_INTERVAL}min, FR:${FR_FETCH_INTERVAL}min, DE:${DE_FETCH_INTERVAL}min`);

  // --- Initial fetches (sequential, each isolated) ---
  if (shouldFetch(FETCH_INTERVAL)) {
    console.log("[cron:ES] No recent data, fetching now...");
    await runFetcher("ES", fetchFromMinisterio);
  } else {
    console.log(`[cron:ES] Data is fresh (last: ${getLastFetchTime()})`);
  }

  if (shouldFetchUK(UK_FETCH_INTERVAL)) {
    console.log("[cron:GB] No recent data, fetching now...");
    await runFetcher("GB", fetchUK);
  }

  if (shouldFetchFrance(FR_FETCH_INTERVAL)) {
    console.log("[cron:FR] No recent data, fetching now...");
    await runFetcher("FR", fetchFrance);
  }

  if (shouldFetchGermany(DE_FETCH_INTERVAL)) {
    console.log("[cron:DE] No recent data, fetching now...");
    await runFetcher("DE", fetchGermany);
  }

  // --- Periodic intervals (each independent) ---
  setInterval(() => runFetcher("ES", fetchFromMinisterio), FETCH_INTERVAL * 60 * 1000);
  setInterval(() => runFetcher("GB", fetchUK), UK_FETCH_INTERVAL * 60 * 1000);
  setInterval(() => runFetcher("FR", fetchFrance), FR_FETCH_INTERVAL * 60 * 1000);
  setInterval(() => runFetcher("DE", fetchGermany), DE_FETCH_INTERVAL * 60 * 1000);
}

// --- Start ---

startCron();

console.log(`[server] GasolinaSmart API running on port ${PORT}`);

export default {
  port: PORT,
  fetch: app.fetch,
};
