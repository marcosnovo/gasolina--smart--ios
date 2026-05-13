import { saveStations, getCountryMetaValue } from "../database";

const API_URL =
  "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/exports/json";

const FUEL_MAP: Record<string, string> = {
  Gazole: "dieselA",
  SP95: "e5",
  SP98: "gasolina98",
  E10: "e10",
  E85: "e85",
  GPLc: "glp",
};

interface FranceRecord {
  id: string;
  adresse?: string;
  ville?: string;
  cp?: string;
  geom?: { lat: number; lon: number };
  prix_nom?: string;
  prix_valeur?: number;
  prix_maj?: string;
  services_service?: string;
  marque?: string;
}

export async function fetchFrance(): Promise<{ count: number; duration: number }> {
  const start = Date.now();
  console.log("[fetcher:FR] Starting fetch from French government API...");

  const response = await fetch(API_URL, {
    headers: {
      Accept: "application/json",
      "User-Agent": "GasolinaSmart-Backend/1.0",
    },
  });

  if (response.status === 429) {
    const retryAfter = parseInt(response.headers.get("Retry-After") || "30");
    console.warn(`[fetcher:FR] Rate limited, waiting ${retryAfter}s...`);
    await new Promise((r) => setTimeout(r, retryAfter * 1000));
    return fetchFrance();
  }

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    console.error(`[fetcher:FR] API returned ${response.status}: ${body.slice(0, 500)}`);
    throw new Error(`France API returned ${response.status}`);
  }

  const raw = await response.text();
  let records: FranceRecord[];
  try {
    const parsed = JSON.parse(raw);
    // Handle both direct array and { results: [...] } response
    records = Array.isArray(parsed) ? parsed : (parsed.results || []);
  } catch {
    console.error(`[fetcher:FR] Failed to parse JSON, first 500 chars: ${raw.slice(0, 500)}`);
    return { count: 0, duration: Date.now() - start };
  }
  console.log(`[fetcher:FR] Received ${records.length} records`);

  // Group by station ID — each record is one fuel price at a station
  const grouped = new Map<
    string,
    {
      first: FranceRecord;
      prices: Record<string, number>;
      latestUpdate: string;
    }
  >();

  for (const rec of records) {
    if (!rec.id || !rec.geom) continue;

    let entry = grouped.get(rec.id);
    if (!entry) {
      entry = { first: rec, prices: {}, latestUpdate: "" };
      grouped.set(rec.id, entry);
    }

    if (rec.prix_nom && rec.prix_valeur != null) {
      const mapped = FUEL_MAP[rec.prix_nom];
      if (mapped && rec.prix_valeur > 0) {
        entry.prices[mapped] = Math.round(rec.prix_valeur * 1000) / 1000;
      }
    }

    if (rec.prix_maj && rec.prix_maj > entry.latestUpdate) {
      entry.latestUpdate = rec.prix_maj;
    }
  }

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

  for (const [stationId, entry] of grouped) {
    if (Object.keys(entry.prices).length === 0) continue;

    const lat = entry.first.geom?.lat ?? 0;
    const lon = entry.first.geom?.lon ?? 0;

    // Validate coordinates are in France
    if (lat < 41.3 || lat > 51.1 || lon < -5.2 || lon > 9.6) continue;

    stations.push({
      id: `FR_${stationId}`,
      name: entry.first.marque || "Station",
      brand: entry.first.marque || "",
      address: entry.first.adresse || "",
      municipality: entry.first.ville || "",
      province: entry.first.cp || "",
      latitude: lat,
      longitude: lon,
      prices: entry.prices,
      updatedAt: entry.latestUpdate || new Date().toISOString(),
    });
  }

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
