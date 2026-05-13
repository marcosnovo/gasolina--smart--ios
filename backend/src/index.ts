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

  // UK
  try {
    const ukRes = await fetch(
      "https://developer.fuel-finder.service.gov.uk/public-api/stations/nearby?latitude=51.5&longitude=-0.12&radius=5",
      { headers: { "User-Agent": "GasolinaSmart-Backend/1.0", Accept: "application/json" } }
    );
    const ukText = await ukRes.text();
    results.uk = {
      status: ukRes.status,
      contentType: ukRes.headers.get("content-type"),
      bodyPreview: ukText.slice(0, 500),
      bodyLength: ukText.length,
    };
  } catch (e) {
    results.uk = { error: String(e) };
  }

  // France (records endpoint with spatial query)
  try {
    const frUrl = new URL("https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/records");
    frUrl.searchParams.set("where", "within_distance(geom, geom'POINT(2.35 48.86)', 5km)");
    frUrl.searchParams.set("limit", "5");
    frUrl.searchParams.set("select", "id,adresse,ville,cp,geom,prix_nom,prix_valeur,prix_maj,marque");
    const frRes = await fetch(frUrl.toString(), {
      headers: { "User-Agent": "GasolinaSmart-Backend/1.0", Accept: "application/json" },
    });
    const frText = await frRes.text();
    results.france = {
      status: frRes.status,
      contentType: frRes.headers.get("content-type"),
      bodyPreview: frText.slice(0, 500),
      bodyLength: frText.length,
    };
  } catch (e) {
    results.france = { error: String(e) };
  }

  // Germany
  const deKey = process.env.TANKERKOENIG_API_KEY;
  if (deKey) {
    try {
      const deRes = await fetch(
        `https://creativecommons.tankerkoenig.de/json/list.php?lat=52.52&lng=13.41&rad=5&sort=dist&type=all&apikey=${deKey}`
      );
      const deText = await deRes.text();
      results.germany = {
        status: deRes.status,
        bodyPreview: deText.slice(0, 500),
        bodyLength: deText.length,
      };
    } catch (e) {
      results.germany = { error: String(e) };
    }
  } else {
    results.germany = { error: "TANKERKOENIG_API_KEY not set" };
  }

  return c.json(results);
});

// --- Cron: periodic fetch ---

async function startCron() {
  console.log(`[cron] ES interval: ${FETCH_INTERVAL}min, GB interval: ${UK_FETCH_INTERVAL}min`);

  // --- Spain ---
  if (shouldFetch(FETCH_INTERVAL)) {
    console.log("[cron:ES] No recent data, fetching now...");
    try {
      await fetchFromMinisterio();
    } catch (e) {
      console.error("[cron:ES] Initial fetch failed:", e);
    }
  } else {
    console.log(`[cron:ES] Data is fresh (last: ${getLastFetchTime()})`);
  }

  setInterval(async () => {
    console.log("[cron:ES] Scheduled fetch starting...");
    try {
      await fetchFromMinisterio();
    } catch (e) {
      console.error("[cron:ES] Fetch failed:", e);
    }
  }, FETCH_INTERVAL * 60 * 1000);

  // --- UK ---
  if (shouldFetchUK(UK_FETCH_INTERVAL)) {
    console.log("[cron:GB] No recent data, fetching now...");
    try {
      await fetchUK();
    } catch (e) {
      console.error("[cron:GB] Initial fetch failed:", e);
    }
  }

  setInterval(async () => {
    console.log("[cron:GB] Scheduled fetch starting...");
    try {
      await fetchUK();
    } catch (e) {
      console.error("[cron:GB] Fetch failed:", e);
    }
  }, UK_FETCH_INTERVAL * 60 * 1000);

  // --- France ---
  if (shouldFetchFrance(FR_FETCH_INTERVAL)) {
    console.log("[cron:FR] No recent data, fetching now...");
    try {
      await fetchFrance();
    } catch (e) {
      console.error("[cron:FR] Initial fetch failed:", e);
    }
  }

  setInterval(async () => {
    console.log("[cron:FR] Scheduled fetch starting...");
    try {
      await fetchFrance();
    } catch (e) {
      console.error("[cron:FR] Fetch failed:", e);
    }
  }, FR_FETCH_INTERVAL * 60 * 1000);

  // --- Germany ---
  if (shouldFetchGermany(DE_FETCH_INTERVAL)) {
    console.log("[cron:DE] No recent data, fetching now...");
    try {
      await fetchGermany();
    } catch (e) {
      console.error("[cron:DE] Initial fetch failed:", e);
    }
  }

  setInterval(async () => {
    console.log("[cron:DE] Scheduled fetch starting...");
    try {
      await fetchGermany();
    } catch (e) {
      console.error("[cron:DE] Fetch failed:", e);
    }
  }, DE_FETCH_INTERVAL * 60 * 1000);
}

// --- Start ---

startCron();

console.log(`[server] GasolinaSmart API running on port ${PORT}`);

export default {
  port: PORT,
  fetch: app.fetch,
};
