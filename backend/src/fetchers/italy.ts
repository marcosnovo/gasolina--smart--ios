import { saveStations, getCountryMetaValue } from "../database";

const ANAGRAFICA_URL = "https://www.mimit.gov.it/images/exportCSV/anagrafica_impianti_attivi.csv";
const PREZZI_URL = "https://www.mimit.gov.it/images/exportCSV/prezzo_alle_8.csv";

export const FUEL_MAP: Record<string, string> = {
  "Benzina": "e5",
  "Benzina Plus": "gasolina98",
  "Benzina speciale": "gasolina98",
  "Benzina Shell V-Power": "gasolina98",
  "Benzina shell v-power": "gasolina98",
  "Gasolio": "dieselA",
  "Gasolio Premium": "dieselPremium",
  "Gasolio speciale": "dieselPremium",
  "Gasolio Shell V-Power": "dieselPremium",
  "Gasolio shell v-power": "dieselPremium",
  "Gasolio artico": "dieselPremium",
  "Gasolio energy": "dieselPremium",
  "Gasolio Energy": "dieselPremium",
  "Gasolio Alpino": "dieselPremium",
  "GPL": "glp",
  "Metano": "gnc",
  "Gas Naturale": "gnc",
  "L-GNC": "gnc",
  "GNL": "gnc",
};

export interface StationData {
  id: string;
  name: string;
  brand: string;
  address: string;
  municipality: string;
  province: string;
  latitude: number;
  longitude: number;
  prices: Record<string, number>;
  latestUpdate: string;
}

export function detectSeparator(line: string): string {
  const pipes = (line.match(/\|/g) || []).length;
  const semis = (line.match(/;/g) || []).length;
  return pipes >= semis ? "|" : ";";
}

export function normalizeBrand(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed) return "";
  return trimmed.charAt(0).toUpperCase() + trimmed.slice(1);
}

export function parseItalianDate(dtComu: string): Date | null {
  // Format: DD/MM/YYYY HH:MM:SS
  const m = dtComu.match(/(\d{2})\/(\d{2})\/(\d{4})\s+(\d{2}):(\d{2}):(\d{2})/);
  if (!m) return null;
  return new Date(`${m[3]}-${m[2]}-${m[1]}T${m[4]}:${m[5]}:${m[6]}`);
}

async function fetchCSV(url: string): Promise<string> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 60_000);

  let response: Response;
  try {
    response = await fetch(url, {
      headers: {
        "User-Agent": "GasolinaSmart-Backend/1.0",
        Accept: "text/csv, */*",
      },
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    throw new Error(`MIMIT ${url.split("/").pop()} returned ${response.status}`);
  }

  const buffer = await response.arrayBuffer();
  const decoder = new TextDecoder("iso-8859-1");
  return decoder.decode(buffer);
}

export interface ParsedAnagrafica {
  stationMap: Map<string, StationData>;
  skippedNoCoords: number;
  skippedOutOfBounds: number;
}

export function parseAnagraficaText(text: string): ParsedAnagrafica {
  const lines = text.split("\n");
  if (lines.length < 3) {
    throw new Error("Anagrafica CSV too short");
  }

  const sep = detectSeparator(lines[2]);
  const stationMap = new Map<string, StationData>();
  let skippedNoCoords = 0;
  let skippedOutOfBounds = 0;

  for (let i = 2; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;

    const cols = line.split(sep);
    if (cols.length < 10) continue;

    const id = cols[0].trim();
    const latStr = cols[8].trim();
    const lonStr = cols[9].trim();

    if (!latStr || !lonStr) {
      skippedNoCoords++;
      continue;
    }

    const lat = parseFloat(latStr);
    const lon = parseFloat(lonStr);

    if (isNaN(lat) || isNaN(lon) || lat === 0 || lon === 0) {
      skippedNoCoords++;
      continue;
    }

    if (lat < 35.5 || lat > 47.1 || lon < 6.6 || lon > 18.5) {
      skippedOutOfBounds++;
      continue;
    }

    stationMap.set(id, {
      id: `IT_${id}`,
      name: (cols[4] || cols[1] || "Stazione").trim(),
      brand: normalizeBrand(cols[2]),
      address: (cols[5] || "").trim(),
      municipality: (cols[6] || "").trim(),
      province: (cols[7] || "").trim(),
      latitude: lat,
      longitude: lon,
      prices: {},
      latestUpdate: "",
    });
  }

  return { stationMap, skippedNoCoords, skippedOutOfBounds };
}

export interface ParsedPrezzi {
  pricesMatched: number;
  pricesUnmapped: number;
  pricesStale: number;
  pricesInvalid: number;
  pricesOrphan: number;
  unmappedFuels: Map<string, number>;
}

export function parsePrezziText(
  text: string,
  stationMap: Map<string, StationData>,
  now: number = Date.now()
): ParsedPrezzi {
  const lines = text.split("\n");
  if (lines.length < 3) {
    throw new Error("Prezzi CSV too short");
  }

  const sep = detectSeparator(lines[2]);
  let pricesMatched = 0;
  let pricesUnmapped = 0;
  let pricesStale = 0;
  let pricesInvalid = 0;
  let pricesOrphan = 0;
  const unmappedFuels = new Map<string, number>();
  const thirtyDaysAgo = now - 30 * 24 * 60 * 60 * 1000;

  for (let i = 2; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;

    const cols = line.split(sep);
    if (cols.length < 5) continue;

    const stationId = cols[0].trim();
    const descCarburante = cols[1].trim();
    const prezzo = parseFloat(cols[2].trim());
    const isSelf = cols[3].trim() === "1";
    const dtComu = cols[4].trim();

    const station = stationMap.get(stationId);
    if (!station) {
      pricesOrphan++;
      continue;
    }

    const mapped = FUEL_MAP[descCarburante];
    if (!mapped) {
      pricesUnmapped++;
      unmappedFuels.set(descCarburante, (unmappedFuels.get(descCarburante) || 0) + 1);
      continue;
    }

    if (isNaN(prezzo) || prezzo <= 0 || prezzo > 5) {
      pricesInvalid++;
      continue;
    }

    const parsedDate = parseItalianDate(dtComu);
    if (parsedDate && parsedDate.getTime() < thirtyDaysAgo) {
      pricesStale++;
      continue;
    }

    const existingPrice = station.prices[mapped];
    if (existingPrice == null || (isSelf && prezzo < existingPrice)) {
      station.prices[mapped] = Math.round(prezzo * 1000) / 1000;
    }

    const dateStr = parsedDate?.toISOString() || "";
    if (dateStr > station.latestUpdate) {
      station.latestUpdate = dateStr;
    }

    pricesMatched++;
  }

  return { pricesMatched, pricesUnmapped, pricesStale, pricesInvalid, pricesOrphan, unmappedFuels };
}

export interface StationOutput {
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
}

export function buildStationList(stationMap: Map<string, StationData>): {
  stations: StationOutput[];
  stationsWithoutPrices: number;
} {
  const stations: StationOutput[] = [];
  let stationsWithoutPrices = 0;

  for (const entry of stationMap.values()) {
    if (Object.keys(entry.prices).length === 0) {
      stationsWithoutPrices++;
      continue;
    }
    stations.push({
      id: entry.id,
      name: entry.name,
      brand: entry.brand,
      address: entry.address,
      municipality: entry.municipality,
      province: entry.province,
      latitude: entry.latitude,
      longitude: entry.longitude,
      prices: entry.prices,
      updatedAt: entry.latestUpdate || new Date().toISOString(),
    });
  }

  return { stations, stationsWithoutPrices };
}

export async function fetchItaly(): Promise<{ count: number; duration: number }> {
  const start = Date.now();
  console.log("[fetcher:IT] Starting fetch from MIMIT (anagrafica + prezzi)...");

  const [anagraficaText, prezziText] = await Promise.all([
    fetchCSV(ANAGRAFICA_URL),
    fetchCSV(PREZZI_URL),
  ]);

  const { stationMap, skippedNoCoords, skippedOutOfBounds } = parseAnagraficaText(anagraficaText);
  console.log(
    `[fetcher:IT] Anagrafica: ${stationMap.size} stations, skipped: ${skippedNoCoords} no-coords, ${skippedOutOfBounds} out-of-bounds`
  );

  const prezziStats = parsePrezziText(prezziText, stationMap);

  const topUnmapped = [...prezziStats.unmappedFuels.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([name, count]) => `"${name}":${count}`);

  console.log(
    `[fetcher:IT] Prezzi: ${prezziStats.pricesMatched} matched, ${prezziStats.pricesUnmapped} unmapped (${topUnmapped.join(", ")}), ${prezziStats.pricesStale} stale, ${prezziStats.pricesInvalid} invalid, ${prezziStats.pricesOrphan} orphan`
  );

  const { stations, stationsWithoutPrices } = buildStationList(stationMap);

  console.log(
    `[fetcher:IT] Final: ${stations.length} stations with prices, ${stationsWithoutPrices} without prices`
  );

  if (stations.length > 0) {
    saveStations("IT", stations);
  }

  const duration = Date.now() - start;
  console.log(`[fetcher:IT] Saved ${stations.length} stations in ${duration}ms`);

  return { count: stations.length, duration };
}

export function shouldFetchItaly(intervalMinutes: number): boolean {
  const last = getCountryMetaValue("IT", "last_fetch");
  if (!last) return true;
  const elapsed = Date.now() - new Date(last).getTime();
  return elapsed > intervalMinutes * 60 * 1000;
}
