import { saveStations, getCountryMetaValue } from "../database";

const API_URL =
  "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/records";

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
  marque?: string;
}

interface FranceAPIResponse {
  total_count: number;
  results: FranceRecord[];
}

const PAGE_SIZE = 100;

// Grid of French cities to cover the country
const FR_GRID: Array<{ lat: number; lng: number; label: string }> = [
  { lat: 48.86, lng: 2.35, label: "Paris" },
  { lat: 43.30, lng: 5.37, label: "Marseille" },
  { lat: 45.76, lng: 4.84, label: "Lyon" },
  { lat: 43.60, lng: 1.44, label: "Toulouse" },
  { lat: 43.71, lng: 7.26, label: "Nice" },
  { lat: 47.22, lng: -1.55, label: "Nantes" },
  { lat: 44.84, lng: -0.58, label: "Bordeaux" },
  { lat: 43.61, lng: 3.88, label: "Montpellier" },
  { lat: 48.58, lng: 7.75, label: "Strasbourg" },
  { lat: 50.63, lng: 3.06, label: "Lille" },
  { lat: 48.11, lng: -1.68, label: "Rennes" },
  { lat: 49.44, lng: 1.10, label: "Rouen" },
  { lat: 49.25, lng: 4.03, label: "Reims" },
  { lat: 47.32, lng: 5.04, label: "Dijon" },
  { lat: 45.19, lng: 5.72, label: "Grenoble" },
  { lat: 46.58, lng: 0.34, label: "Poitiers" },
  { lat: 47.39, lng: 0.69, label: "Tours" },
  { lat: 48.39, lng: -4.49, label: "Brest" },
  { lat: 46.81, lng: -1.43, label: "La Roche-sur-Yon" },
  { lat: 45.83, lng: 1.26, label: "Limoges" },
  { lat: 44.56, lng: 6.08, label: "Gap" },
  { lat: 42.70, lng: 2.90, label: "Perpignan" },
  { lat: 46.15, lng: -1.15, label: "La Rochelle" },
  { lat: 48.00, lng: 0.20, label: "Le Mans" },
  { lat: 49.90, lng: 2.30, label: "Amiens" },
  { lat: 45.45, lng: 4.39, label: "Saint-Étienne" },
  { lat: 44.10, lng: -0.78, label: "Mont-de-Marsan" },
  { lat: 47.00, lng: 2.40, label: "Bourges" },
  { lat: 48.45, lng: -2.76, label: "Saint-Brieuc" },
  { lat: 41.92, lng: 8.74, label: "Ajaccio" },
];

const SEARCH_RADIUS_KM = 50;

async function fetchArea(lat: number, lng: number): Promise<FranceRecord[]> {
  const whereClause = `within_distance(geom, geom'POINT(${lng} ${lat})', ${SEARCH_RADIUS_KM}km)`;

  const url = new URL(API_URL);
  url.searchParams.set("where", whereClause);
  url.searchParams.set("limit", String(PAGE_SIZE));
  url.searchParams.set("select", "id,adresse,ville,cp,geom,prix_nom,prix_valeur,prix_maj,marque");

  const response = await fetch(url.toString(), {
    headers: {
      "User-Agent": "GasolinaSmart-Backend/1.0",
      Accept: "application/json",
    },
  });

  if (response.status === 429) {
    const retryAfter = parseInt(response.headers.get("Retry-After") || "10");
    console.warn(`[fetcher:FR] Rate limited, waiting ${retryAfter}s...`);
    await new Promise((r) => setTimeout(r, retryAfter * 1000));
    return fetchArea(lat, lng);
  }

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    console.error(`[fetcher:FR] API returned ${response.status}: ${body.slice(0, 300)}`);
    return [];
  }

  const raw = await response.json() as FranceAPIResponse;
  return raw.results || [];
}

export async function fetchFrance(): Promise<{ count: number; duration: number }> {
  const start = Date.now();
  console.log(`[fetcher:FR] Starting fetch from French government API (${FR_GRID.length} points)...`);

  const seen = new Map<
    string,
    {
      first: FranceRecord;
      prices: Record<string, number>;
      latestUpdate: string;
    }
  >();

  for (const point of FR_GRID) {
    try {
      const records = await fetchArea(point.lat, point.lng);

      for (const rec of records) {
        if (!rec.id || !rec.geom) continue;

        let entry = seen.get(rec.id);
        if (!entry) {
          entry = { first: rec, prices: {}, latestUpdate: "" };
          seen.set(rec.id, entry);
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

      console.log(`[fetcher:FR] ${point.label}: +${records.length} records, ${seen.size} unique stations`);
    } catch (e) {
      console.error(`[fetcher:FR] Failed for ${point.label}:`, e);
    }
    await new Promise((r) => setTimeout(r, 300));
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

  for (const [stationId, entry] of seen) {
    if (Object.keys(entry.prices).length === 0) continue;

    const lat = entry.first.geom?.lat ?? 0;
    const lon = entry.first.geom?.lon ?? 0;

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
