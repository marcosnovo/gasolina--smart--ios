import { saveStations, getCountryMetaValue } from "../database";
import type { StationInput } from "../database";

const BASE_URL = "https://developer.fuel-finder.service.gov.uk/public-api";

const FUEL_MAP: Record<string, string> = {
  E10: "e10",
  E5: "e5",
  B7: "dieselA",
  SDV: "dieselPremium",
  SUL: "gasolina98",
};

interface UKStation {
  station_id: string;
  brand: string;
  name: string;
  address: {
    line1?: string;
    town?: string;
    county?: string;
    postcode?: string;
  };
  location: { latitude: number; longitude: number };
  prices: Array<{ fuel_type: string; price: number; updated_at: string }>;
}

const UK_GRID: Array<{ lat: number; lng: number; label: string }> = [
  { lat: 51.51, lng: -0.13, label: "London" },
  { lat: 52.48, lng: -1.89, label: "Birmingham" },
  { lat: 53.48, lng: -2.24, label: "Manchester" },
  { lat: 53.80, lng: -1.55, label: "Leeds" },
  { lat: 55.95, lng: -3.19, label: "Edinburgh" },
  { lat: 55.86, lng: -4.25, label: "Glasgow" },
  { lat: 51.45, lng: -2.59, label: "Bristol" },
  { lat: 53.38, lng: -1.47, label: "Sheffield" },
  { lat: 54.97, lng: -1.61, label: "Newcastle" },
  { lat: 53.41, lng: -2.99, label: "Liverpool" },
  { lat: 52.63, lng: -1.13, label: "Leicester" },
  { lat: 52.95, lng: -1.15, label: "Nottingham" },
  { lat: 50.72, lng: -1.88, label: "Bournemouth" },
  { lat: 50.37, lng: -4.14, label: "Plymouth" },
  { lat: 51.88, lng: -2.08, label: "Gloucester" },
  { lat: 52.20, lng: 0.12, label: "Cambridge" },
  { lat: 51.38, lng: 1.44, label: "Canterbury" },
  { lat: 50.84, lng: -0.14, label: "Brighton" },
  { lat: 51.75, lng: -1.26, label: "Oxford" },
  { lat: 54.52, lng: -6.04, label: "Belfast" },
  { lat: 51.48, lng: -3.18, label: "Cardiff" },
  { lat: 56.46, lng: -2.97, label: "Dundee" },
  { lat: 57.15, lng: -2.09, label: "Aberdeen" },
  { lat: 53.23, lng: -0.54, label: "Lincoln" },
  { lat: 52.05, lng: -0.76, label: "Milton Keynes" },
  { lat: 50.91, lng: -1.40, label: "Southampton" },
  { lat: 52.41, lng: -1.51, label: "Coventry" },
  { lat: 54.57, lng: -1.24, label: "Middlesbrough" },
  { lat: 53.96, lng: -1.08, label: "York" },
  { lat: 51.07, lng: -4.06, label: "Barnstaple" },
  { lat: 50.26, lng: -5.05, label: "Truro" },
];

const SEARCH_RADIUS_MILES = 25;

async function fetchNearby(lat: number, lng: number): Promise<UKStation[]> {
  const url = `${BASE_URL}/stations/nearby?latitude=${lat}&longitude=${lng}&radius=${SEARCH_RADIUS_MILES}`;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15_000);

  let response: Response;
  try {
    response = await fetch(url, {
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
    if (response.status === 429) {
      const retryAfter = parseInt(response.headers.get("Retry-After") || "5");
      console.warn(`[fetcher:GB] Rate limited, waiting ${retryAfter}s...`);
      await new Promise((r) => setTimeout(r, retryAfter * 1000));
      return fetchNearby(lat, lng);
    }
    throw new Error(`UK API returned ${response.status}`);
  }

  const raw = await response.text();
  let data: { stations?: UKStation[] } | UKStation[];
  try {
    data = JSON.parse(raw);
  } catch {
    console.error(`[fetcher:GB] Failed to parse JSON: ${raw.slice(0, 200)}`);
    return [];
  }

  return Array.isArray(data) ? data : data.stations || [];
}

function mapStation(dto: UKStation): StationInput | null {
  const prices: Record<string, number> = {};
  let latestUpdate = "";

  for (const p of dto.prices) {
    const mapped = FUEL_MAP[p.fuel_type];
    if (!mapped) continue;
    // UK prices are in pence; convert to pounds (3 decimals).
    prices[mapped] = Math.round((p.price / 100) * 1000) / 1000;
    if (p.updated_at > latestUpdate) latestUpdate = p.updated_at;
  }

  if (Object.keys(prices).length === 0) return null;

  const address = [dto.address.line1, dto.address.town, dto.address.postcode]
    .filter((s) => s && s.length > 0)
    .join(", ");

  return {
    id: `GB_${dto.station_id}`,
    name: dto.name || dto.brand,
    brand: dto.brand,
    address,
    municipality: dto.address.town || "",
    province: dto.address.county || "",
    latitude: dto.location.latitude,
    longitude: dto.location.longitude,
    prices,
    updatedAt: latestUpdate || new Date().toISOString(),
  };
}

export async function fetchUK(db: D1Database): Promise<{ count: number; duration: number }> {
  const start = Date.now();
  const total = UK_GRID.length;
  console.log(`[fetcher:GB] Starting fetch from UK Fuel Finder API (${total} points)...`);

  const seen = new Set<string>();
  const allStations: StationInput[] = [];
  let failedCount = 0;
  let lastPointError = "";

  for (const point of UK_GRID) {
    try {
      const stations = await fetchNearby(point.lat, point.lng);
      for (const dto of stations) {
        const key = `GB_${dto.station_id}`;
        if (seen.has(key)) continue;
        seen.add(key);
        const mapped = mapStation(dto);
        if (mapped) allStations.push(mapped);
      }
      console.log(`[fetcher:GB] ${point.label}: +${stations.length} raw, ${seen.size} unique total`);
    } catch (e) {
      failedCount++;
      lastPointError = e instanceof Error ? e.message : String(e);
      console.error(`[fetcher:GB] Failed for ${point.label}: ${lastPointError}`);
    }
    await new Promise((r) => setTimeout(r, 200));
  }

  if (failedCount === total) {
    throw new Error(`${failedCount}/${total} grid points failed. Last error: ${lastPointError}`);
  }

  if (allStations.length > 0) {
    await saveStations(db, "GB", allStations);
  }

  const duration = Date.now() - start;
  const failNote = failedCount > 0 ? ` (${failedCount}/${total} points failed)` : "";
  console.log(`[fetcher:GB] Saved ${allStations.length} stations in ${duration}ms${failNote}`);

  return { count: allStations.length, duration };
}

export async function shouldFetchUK(db: D1Database, intervalMinutes: number): Promise<boolean> {
  const last = await getCountryMetaValue(db, "GB", "last_fetch");
  if (!last) return true;
  const elapsed = Date.now() - new Date(last).getTime();
  return elapsed > intervalMinutes * 60 * 1000;
}
