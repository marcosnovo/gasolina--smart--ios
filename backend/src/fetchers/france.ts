import { saveStations, getCountryMetaValue } from "../database";

const API_URL =
  "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/exports/json";

interface FranceExportRecord {
  id: number;
  adresse?: string;
  ville?: string;
  cp?: string;
  departement?: string;
  region?: string;
  geom?: { lat: number; lon: number };
  gazole_prix?: number | null;
  gazole_maj?: string | null;
  sp95_prix?: number | null;
  sp95_maj?: string | null;
  sp98_prix?: number | null;
  sp98_maj?: string | null;
  e10_prix?: number | null;
  e10_maj?: string | null;
  e85_prix?: number | null;
  e85_maj?: string | null;
  gplc_prix?: number | null;
  gplc_maj?: string | null;
}

const FUEL_FIELDS: Array<{
  priceKey: keyof FranceExportRecord;
  majKey: keyof FranceExportRecord;
  fuelType: string;
}> = [
  { priceKey: "gazole_prix", majKey: "gazole_maj", fuelType: "dieselA" },
  { priceKey: "sp95_prix", majKey: "sp95_maj", fuelType: "e5" },
  { priceKey: "sp98_prix", majKey: "sp98_maj", fuelType: "gasolina98" },
  { priceKey: "e10_prix", majKey: "e10_maj", fuelType: "e10" },
  { priceKey: "e85_prix", majKey: "e85_maj", fuelType: "e85" },
  { priceKey: "gplc_prix", majKey: "gplc_maj", fuelType: "glp" },
];

export async function fetchFrance(): Promise<{ count: number; duration: number }> {
  const start = Date.now();
  console.log("[fetcher:FR] Starting fetch from French government API (full export)...");

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 60_000);

  let response: Response;
  try {
    response = await fetch(API_URL, {
      headers: {
        "User-Agent": "GasolinaSmart-Backend/1.0",
        Accept: "application/json",
      },
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    throw new Error(`France API returned ${response.status}`);
  }

  const records = (await response.json()) as FranceExportRecord[];
  console.log(`[fetcher:FR] Received ${records.length} records from export`);

  let skippedNoGeo = 0;
  let skippedNoPrices = 0;
  let skippedOutOfBounds = 0;

  const stations: Array<{
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
  }> = [];

  for (const rec of records) {
    if (!rec.geom || rec.geom.lat == null || rec.geom.lon == null || isNaN(rec.geom.lat) || isNaN(rec.geom.lon)) {
      skippedNoGeo++;
      continue;
    }

    const lat = rec.geom.lat;
    const lon = rec.geom.lon;

    if (lat < 41.3 || lat > 51.1 || lon < -5.2 || lon > 9.6) {
      skippedOutOfBounds++;
      continue;
    }

    const prices: Record<string, number> = {};
    let latestUpdate = "";

    for (const fuel of FUEL_FIELDS) {
      const price = rec[fuel.priceKey] as number | null | undefined;
      if (price != null && price > 0) {
        prices[fuel.fuelType] = Math.round(price * 1000) / 1000;
      }
      const maj = rec[fuel.majKey] as string | null | undefined;
      if (maj && maj > latestUpdate) {
        latestUpdate = maj;
      }
    }

    if (Object.keys(prices).length === 0) {
      skippedNoPrices++;
      continue;
    }

    stations.push({
      id: `FR_${rec.id}`,
      name: rec.ville || "Station",
      brand: "",
      address: rec.adresse || "",
      municipality: rec.ville || "",
      province: rec.departement || rec.cp || "",
      latitude: lat,
      longitude: lon,
      prices,
      updatedAt: latestUpdate || new Date().toISOString(),
    });
  }

  console.log(
    `[fetcher:FR] Parsed: ${stations.length} valid, skipped: ${skippedNoGeo} no-geo, ${skippedNoPrices} no-prices, ${skippedOutOfBounds} out-of-bounds`
  );

  if (stations.length > 0) {
    saveStations("FR", stations);
  }

  const duration = Date.now() - start;
  console.log(`[fetcher:FR] Saved ${stations.length} stations in ${duration}ms`);

  return { count: stations.length, duration };
}

export function shouldFetchFrance(intervalMinutes: number): boolean {
  const last = getCountryMetaValue("FR", "last_fetch");
  if (!last) return true;
  const elapsed = Date.now() - new Date(last).getTime();
  return elapsed > intervalMinutes * 60 * 1000;
}
