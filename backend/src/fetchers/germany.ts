import { saveStations, getCountryMetaValue } from "../database";

const BASE_URL = "https://creativecommons.tankerkoenig.de/json/list.php";

const TANKERKOENIG_API_KEY = process.env.TANKERKOENIG_API_KEY || "";

interface TKStation {
  id: string;
  name: string;
  brand: string;
  street: string;
  houseNumber?: string;
  postCode?: string;
  place: string;
  lat: number;
  lng: number;
  dist: number;
  diesel?: number;
  e5?: number;
  e10?: number;
  isOpen: boolean;
}

interface TKResponse {
  ok: boolean;
  stations?: TKStation[];
  message?: string;
}

// 16 Bundesland capitals + ~30 major cities for comprehensive coverage
const DE_GRID: Array<{ lat: number; lng: number; label: string }> = [
  // Bundesland capitals
  { lat: 52.52, lng: 13.41, label: "Berlin" },
  { lat: 53.55, lng: 10.00, label: "Hamburg" },
  { lat: 48.14, lng: 11.58, label: "München" },
  { lat: 50.94, lng: 6.96, label: "Köln" },
  { lat: 50.11, lng: 8.68, label: "Frankfurt" },
  { lat: 48.78, lng: 9.18, label: "Stuttgart" },
  { lat: 51.23, lng: 6.78, label: "Düsseldorf" },
  { lat: 51.34, lng: 12.37, label: "Leipzig" },
  { lat: 51.05, lng: 13.74, label: "Dresden" },
  { lat: 52.38, lng: 9.74, label: "Hannover" },
  { lat: 49.45, lng: 11.08, label: "Nürnberg" },
  { lat: 53.08, lng: 8.80, label: "Bremen" },
  { lat: 54.32, lng: 10.14, label: "Kiel" },
  { lat: 52.13, lng: 11.63, label: "Magdeburg" },
  { lat: 50.98, lng: 11.03, label: "Erfurt" },
  { lat: 49.24, lng: 6.99, label: "Saarbrücken" },
  { lat: 53.63, lng: 11.42, label: "Schwerin" },
  { lat: 52.41, lng: 12.53, label: "Potsdam" },
  { lat: 50.08, lng: 14.44, label: "Mainz" },
  // Major cities for gap coverage
  { lat: 51.48, lng: 7.22, label: "Dortmund" },
  { lat: 51.45, lng: 7.01, label: "Essen" },
  { lat: 51.51, lng: 7.47, label: "Bochum" },
  { lat: 51.96, lng: 7.63, label: "Münster" },
  { lat: 49.01, lng: 8.40, label: "Karlsruhe" },
  { lat: 49.49, lng: 8.47, label: "Mannheim" },
  { lat: 48.40, lng: 10.00, label: "Augsburg" },
  { lat: 47.99, lng: 7.85, label: "Freiburg" },
  { lat: 50.78, lng: 6.08, label: "Aachen" },
  { lat: 51.76, lng: 14.33, label: "Cottbus" },
  { lat: 54.09, lng: 12.10, label: "Rostock" },
  { lat: 50.93, lng: 13.53, label: "Chemnitz" },
  { lat: 48.37, lng: 10.90, label: "München-Ost" },
  { lat: 47.66, lng: 9.18, label: "Konstanz" },
  { lat: 49.80, lng: 9.94, label: "Würzburg" },
  { lat: 48.69, lng: 9.14, label: "Böblingen" },
  { lat: 51.16, lng: 10.45, label: "Mühlhausen" },
  { lat: 50.35, lng: 7.60, label: "Koblenz" },
  { lat: 47.42, lng: 10.99, label: "Inntal/Garmisch" },
  { lat: 49.87, lng: 8.65, label: "Darmstadt" },
  { lat: 51.43, lng: 6.77, label: "Duisburg" },
];

const MAX_RADIUS = 25;

async function fetchArea(lat: number, lng: number): Promise<TKStation[]> {
  if (!TANKERKOENIG_API_KEY) {
    throw new Error("TANKERKOENIG_API_KEY not set");
  }

  const url = `${BASE_URL}?lat=${lat}&lng=${lng}&rad=${MAX_RADIUS}&sort=dist&type=all&apikey=${TANKERKOENIG_API_KEY}`;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15_000);

  let response: Response;
  try {
    response = await fetch(url, { signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    if (response.status === 503) {
      console.warn("[fetcher:DE] API temporarily unavailable, waiting 5s...");
      await new Promise((r) => setTimeout(r, 5000));
      return fetchArea(lat, lng);
    }
    throw new Error(`Tankerkoenig API returned ${response.status}`);
  }

  const data = (await response.json()) as TKResponse;

  if (!data.ok) {
    throw new Error(`Tankerkoenig API error: ${data.message}`);
  }

  return data.stations || [];
}

export async function fetchGermany(): Promise<{ count: number; duration: number }> {
  if (!TANKERKOENIG_API_KEY) {
    console.warn("[fetcher:DE] TANKERKOENIG_API_KEY not set, skipping.");
    return { count: 0, duration: 0 };
  }

  const start = Date.now();
  console.log(`[fetcher:DE] Starting fetch from Tankerkoenig API (${DE_GRID.length} points)...`);

  const seen = new Set<string>();
  const allStations: Array<{
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

  const now = new Date().toISOString();

  for (const point of DE_GRID) {
    try {
      const stations = await fetchArea(point.lat, point.lng);

      for (const dto of stations) {
        if (!dto.isOpen) continue;
        const key = dto.id;
        if (seen.has(key)) continue;
        seen.add(key);

        const prices: Record<string, number> = {};
        if (dto.e5 != null && dto.e5 > 0) prices["e5"] = Math.round(dto.e5 * 1000) / 1000;
        if (dto.e10 != null && dto.e10 > 0) prices["e10"] = Math.round(dto.e10 * 1000) / 1000;
        if (dto.diesel != null && dto.diesel > 0) prices["dieselA"] = Math.round(dto.diesel * 1000) / 1000;

        if (Object.keys(prices).length === 0) continue;

        // Validate coordinates in Germany
        if (dto.lat < 47.3 || dto.lat > 55.1 || dto.lng < 5.9 || dto.lng > 15.0) continue;

        const address = dto.houseNumber
          ? `${dto.street} ${dto.houseNumber}`
          : dto.street;

        allStations.push({
          id: `DE_${dto.id}`,
          name: dto.name,
          brand: dto.brand,
          address,
          municipality: dto.place,
          province: dto.postCode || "",
          latitude: dto.lat,
          longitude: dto.lng,
          prices,
          updatedAt: now,
        });
      }

      console.log(`[fetcher:DE] ${point.label}: +${stations.length} raw, ${seen.size} unique total`);
    } catch (e) {
      console.error(`[fetcher:DE] Failed for ${point.label}:`, e);
    }
    // Respect rate limits — small delay between requests
    await new Promise((r) => setTimeout(r, 250));
  }

  if (allStations.length > 0) {
    saveStations("DE", allStations);
  }

  const duration = Date.now() - start;
  console.log(`[fetcher:DE] Saved ${allStations.length} stations in ${duration}ms`);

  return { count: allStations.length, duration };
}

export function shouldFetchGermany(intervalMinutes: number): boolean {
  const last = getCountryMetaValue("DE", "last_fetch");
  if (!last) return true;
  const elapsed = Date.now() - new Date(last).getTime();
  return elapsed > intervalMinutes * 60 * 1000;
}
