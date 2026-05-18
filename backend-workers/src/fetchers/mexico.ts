import { saveStations, getCountryMetaValue } from "../database";
import type { StationInput } from "../database";

// Comisión Reguladora de Energía (CRE) — México publishes two daily XML
// feeds: one with station metadata + coordinates ("places") and one with
// the price of regular, premium and diesel per station ("prices"). They
// join on `place_id`. Both feeds cover the ~12,500 active retail stations
// in the country. Source documentation:
// https://datos.gob.mx/busca/dataset/precios-vigentes-de-gasolinas-y-diesel
const PLACES_URL = "https://publicacionexterna.azurewebsites.net/publicaciones/places";
const PRICES_URL = "https://publicacionexterna.azurewebsites.net/publicaciones/prices";

// CRE uses three product categories; we map them onto our shared fuel
// enum so the iOS UI and widgets keep working without Mexico-specific
// branches:
//   regular ("Magna", 87 octanos) → gasolina95 (closest analogue)
//   premium ("Premium", ≥91 octanos) → gasolina98
//   diesel  → dieselA
const FUEL_MAP: Record<string, string> = {
  regular: "gasolina95",
  premium: "gasolina98",
  diesel: "dieselA",
};

// CONUS-equivalent bounding box for Mexico. Throws out the rare CRE
// stations with junk coordinates (lat=0, lon=0 or sitting on top of
// other countries).
const MIN_LAT = 14.5;
const MAX_LAT = 32.8;
const MIN_LON = -118.5;
const MAX_LON = -86.5;

interface StationData {
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

async function fetchXML(url: string): Promise<string> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 60_000);

  let response: Response;
  try {
    response = await fetch(url, {
      headers: {
        "User-Agent": "GasolinaSmart-Backend/1.0",
        Accept: "application/xml, text/xml, */*",
      },
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    throw new Error(`CRE ${url.split("/").pop()} returned ${response.status}`);
  }

  return await response.text();
}

function decodeXML(s: string): string {
  return s
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&")
    .trim();
}

// Regex-based parse: the CRE XML is shallow and well-formed, so we can
// extract `<place>` blocks and pluck the inner fields without pulling in
// a real XML parser (would blow up the Worker bundle for ~150 LOC of
// markup).
const PLACE_BLOCK_RE = /<place\s+place_id="(\d+)"[^>]*>([\s\S]*?)<\/place>/g;
const NAME_RE = /<name>([\s\S]*?)<\/name>/;
const CRE_ID_RE = /<cre_id>([\s\S]*?)<\/cre_id>/;
const LEGAL_NAME_RE = /<legal_name>([\s\S]*?)<\/legal_name>/;
const X_RE = /<x>([^<]+)<\/x>/;
const Y_RE = /<y>([^<]+)<\/y>/;
const PRICE_BLOCK_RE = /<gas_price\s+type="(\w+)"[^>]*>([\d.]+)<\/gas_price>/g;

function parsePlaces(text: string): {
  stations: Map<string, StationData>;
  skippedNoCoords: number;
  skippedOutOfBounds: number;
} {
  const stations = new Map<string, StationData>();
  let skippedNoCoords = 0;
  let skippedOutOfBounds = 0;

  PLACE_BLOCK_RE.lastIndex = 0;
  let match: RegExpExecArray | null;
  while ((match = PLACE_BLOCK_RE.exec(text)) !== null) {
    const placeId = match[1];
    const body = match[2];

    const xMatch = body.match(X_RE);
    const yMatch = body.match(Y_RE);
    if (!xMatch || !yMatch) {
      skippedNoCoords++;
      continue;
    }

    const lon = parseFloat(xMatch[1]);
    const lat = parseFloat(yMatch[1]);
    if (!Number.isFinite(lat) || !Number.isFinite(lon) || lat === 0 || lon === 0) {
      skippedNoCoords++;
      continue;
    }

    if (lat < MIN_LAT || lat > MAX_LAT || lon < MIN_LON || lon > MAX_LON) {
      skippedOutOfBounds++;
      continue;
    }

    const name = decodeXML(body.match(NAME_RE)?.[1] ?? "Gasolinera");
    const legal = decodeXML(body.match(LEGAL_NAME_RE)?.[1] ?? "");
    const creId = decodeXML(body.match(CRE_ID_RE)?.[1] ?? "");

    stations.set(placeId, {
      id: `MX_${placeId}`,
      name,
      // The CRE feed doesn't expose a clean brand field. The legal name
      // is usually "PEMEX FRANQUICIA …" or "GASOLINERA … S.A. DE C.V.";
      // we surface it as-is so the UI shows *something* meaningful and
      // the user can recognise it. A future improvement would be to
      // extract the brand by regex (PEMEX / Shell / BP / Mobil / …).
      brand: legal || creId,
      address: "",
      municipality: "",
      province: "",
      latitude: lat,
      longitude: lon,
      prices: {},
      updatedAt: "",
    });
  }

  return { stations, skippedNoCoords, skippedOutOfBounds };
}

function parsePrices(
  text: string,
  stations: Map<string, StationData>,
  now: number = Date.now()
): {
  pricesMatched: number;
  pricesUnmapped: number;
  pricesInvalid: number;
  pricesOrphan: number;
} {
  let pricesMatched = 0;
  let pricesUnmapped = 0;
  let pricesInvalid = 0;
  let pricesOrphan = 0;
  const nowIso = new Date(now).toISOString();

  PLACE_BLOCK_RE.lastIndex = 0;
  let match: RegExpExecArray | null;
  while ((match = PLACE_BLOCK_RE.exec(text)) !== null) {
    const placeId = match[1];
    const body = match[2];

    const station = stations.get(placeId);
    if (!station) {
      pricesOrphan++;
      continue;
    }

    PRICE_BLOCK_RE.lastIndex = 0;
    let pm: RegExpExecArray | null;
    while ((pm = PRICE_BLOCK_RE.exec(body)) !== null) {
      const type = pm[1].toLowerCase();
      const value = parseFloat(pm[2]);
      const mapped = FUEL_MAP[type];
      if (!mapped) {
        pricesUnmapped++;
        continue;
      }
      // Mexican retail prices are in MXN/L. Sanity range: ~10 to ~50.
      if (!Number.isFinite(value) || value < 5 || value > 80) {
        pricesInvalid++;
        continue;
      }
      station.prices[mapped] = Math.round(value * 1000) / 1000;
      pricesMatched++;
    }

    if (Object.keys(station.prices).length > 0) {
      station.updatedAt = nowIso;
    }
  }

  return { pricesMatched, pricesUnmapped, pricesInvalid, pricesOrphan };
}

function buildStationList(stations: Map<string, StationData>): {
  stations: StationInput[];
  stationsWithoutPrices: number;
} {
  const out: StationInput[] = [];
  let stationsWithoutPrices = 0;
  for (const entry of stations.values()) {
    if (Object.keys(entry.prices).length === 0) {
      stationsWithoutPrices++;
      continue;
    }
    out.push({
      id: entry.id,
      name: entry.name,
      brand: entry.brand,
      address: entry.address,
      municipality: entry.municipality,
      province: entry.province,
      latitude: entry.latitude,
      longitude: entry.longitude,
      prices: entry.prices,
      updatedAt: entry.updatedAt || new Date().toISOString(),
    });
  }
  return { stations: out, stationsWithoutPrices };
}

export async function fetchMexico(db: D1Database): Promise<{ count: number; duration: number }> {
  const start = Date.now();
  console.log("[fetcher:MX] Starting fetch from CRE (places + prices)...");

  const [placesText, pricesText] = await Promise.all([
    fetchXML(PLACES_URL),
    fetchXML(PRICES_URL),
  ]);

  const { stations, skippedNoCoords, skippedOutOfBounds } = parsePlaces(placesText);
  console.log(
    `[fetcher:MX] Places: ${stations.size} stations, skipped: ${skippedNoCoords} no-coords, ${skippedOutOfBounds} out-of-bounds`
  );

  const priceStats = parsePrices(pricesText, stations);
  console.log(
    `[fetcher:MX] Prices: ${priceStats.pricesMatched} matched, ${priceStats.pricesUnmapped} unmapped, ${priceStats.pricesInvalid} invalid, ${priceStats.pricesOrphan} orphan`
  );

  const { stations: stationList, stationsWithoutPrices } = buildStationList(stations);
  console.log(
    `[fetcher:MX] Final: ${stationList.length} stations with prices, ${stationsWithoutPrices} without`
  );

  if (stationList.length > 0) {
    await saveStations(db, "MX", stationList);
  }

  const duration = Date.now() - start;
  console.log(`[fetcher:MX] Saved ${stationList.length} stations in ${duration}ms`);

  return { count: stationList.length, duration };
}

export async function shouldFetchMexico(db: D1Database, intervalMinutes: number): Promise<boolean> {
  const last = await getCountryMetaValue(db, "MX", "last_fetch");
  if (!last) return true;
  const elapsed = Date.now() - new Date(last).getTime();
  return elapsed > intervalMinutes * 60 * 1000;
}
