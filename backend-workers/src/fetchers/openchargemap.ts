import { saveChargingStations, getCountryMetaValue } from "../database";
import type { ChargingStationInput, ChargingConnectionInput } from "../database";

// OpenChargeMap is purpose-built for EV charging data and has connector-level
// detail that OpenStreetMap doesn't. The free API tier needs an API key
// registered at https://openchargemap.org/site/profile/applications and is set
// as the OPENCHARGEMAP_API_KEY worker secret.
const API_URL = "https://api.openchargemap.io/v3/poi/";

// OCM's free tier hard-caps results at 5000 per request and does not honour
// `offset` for true pagination. To cover whole countries we partition each
// country into bounding boxes and request up to 5000 stations per box —
// 4 quadrants × 5000 = 20k stations max per country, well above the real
// totals (Spain ~25k including private chargers, but ~12k are publicly
// listed on OCM).
const PAGE_SIZE = 5000;

interface BBox {
  minLat: number;
  maxLat: number;
  minLon: number;
  maxLon: number;
  label: string;
}

const COUNTRY_BBOXES: Record<string, BBox[]> = {
  ES: [
    // Excludes Canarias deliberately; OCM coverage there is minimal and the
    // wider box would dilute results.
    { minLat: 27.5, maxLat: 38.5, minLon: -10, maxLon: -3, label: "ES-SW" },
    { minLat: 27.5, maxLat: 38.5, minLon: -3, maxLon: 4.4, label: "ES-SE" },
    { minLat: 38.5, maxLat: 43.8, minLon: -10, maxLon: -3, label: "ES-NW" },
    { minLat: 38.5, maxLat: 43.8, minLon: -3, maxLon: 4.4, label: "ES-NE" },
  ],
  FR: [
    { minLat: 41.3, maxLat: 46.5, minLon: -5.2, maxLon: 2.5, label: "FR-SW" },
    { minLat: 41.3, maxLat: 46.5, minLon: 2.5, maxLon: 9.6, label: "FR-SE" },
    { minLat: 46.5, maxLat: 51.1, minLon: -5.2, maxLon: 2.5, label: "FR-NW" },
    { minLat: 46.5, maxLat: 51.1, minLon: 2.5, maxLon: 9.6, label: "FR-NE" },
  ],
  GB: [
    { minLat: 49.9, maxLat: 53.5, minLon: -8.2, maxLon: -3, label: "GB-SW" },
    { minLat: 49.9, maxLat: 53.5, minLon: -3, maxLon: 1.8, label: "GB-SE" },
    { minLat: 53.5, maxLat: 60.9, minLon: -8.2, maxLon: -3, label: "GB-NW" },
    { minLat: 53.5, maxLat: 60.9, minLon: -3, maxLon: 1.8, label: "GB-NE" },
  ],
  DE: [
    { minLat: 47.3, maxLat: 51.2, minLon: 5.9, maxLon: 10.5, label: "DE-SW" },
    { minLat: 47.3, maxLat: 51.2, minLon: 10.5, maxLon: 15, label: "DE-SE" },
    { minLat: 51.2, maxLat: 55.1, minLon: 5.9, maxLon: 10.5, label: "DE-NW" },
    { minLat: 51.2, maxLat: 55.1, minLon: 10.5, maxLon: 15, label: "DE-NE" },
  ],
  IT: [
    { minLat: 35.5, maxLat: 41.5, minLon: 6.6, maxLon: 18.5, label: "IT-S" },
    { minLat: 41.5, maxLat: 44.5, minLon: 6.6, maxLon: 18.5, label: "IT-C" },
    { minLat: 44.5, maxLat: 47.1, minLon: 6.6, maxLon: 18.5, label: "IT-N" },
  ],
  // USA: CONUS plus AK and HI. The USA has ~70-80k public chargers on
  // OpenChargeMap — well above the 5000-per-request cap — so we use a
  // 4×4 CONUS grid plus single boxes for Alaska and Hawaii. Coastal
  // boxes (CA + NY metro) skirt the cap; if a box logs exactly 5000
  // raw POIs we should subdivide that quadrant.
  US: [
    // CONUS row 1 (south): 24.5°N–31.0°N
    { minLat: 24.5, maxLat: 31.0, minLon: -125, maxLon: -110.4, label: "US-SW1" },
    { minLat: 24.5, maxLat: 31.0, minLon: -110.4, maxLon: -95.7, label: "US-SW2" },
    { minLat: 24.5, maxLat: 31.0, minLon: -95.7, maxLon: -81.1, label: "US-SE1" },
    { minLat: 24.5, maxLat: 31.0, minLon: -81.1, maxLon: -66.5, label: "US-SE2" },
    // CONUS row 2: 31.0°N–37.5°N
    { minLat: 31.0, maxLat: 37.5, minLon: -125, maxLon: -110.4, label: "US-MW1" },
    { minLat: 31.0, maxLat: 37.5, minLon: -110.4, maxLon: -95.7, label: "US-MW2" },
    { minLat: 31.0, maxLat: 37.5, minLon: -95.7, maxLon: -81.1, label: "US-ME1" },
    { minLat: 31.0, maxLat: 37.5, minLon: -81.1, maxLon: -66.5, label: "US-ME2" },
    // CONUS row 3: 37.5°N–43.5°N
    { minLat: 37.5, maxLat: 43.5, minLon: -125, maxLon: -110.4, label: "US-CW1" },
    { minLat: 37.5, maxLat: 43.5, minLon: -110.4, maxLon: -95.7, label: "US-CW2" },
    { minLat: 37.5, maxLat: 43.5, minLon: -95.7, maxLon: -81.1, label: "US-CE1" },
    { minLat: 37.5, maxLat: 43.5, minLon: -81.1, maxLon: -66.5, label: "US-CE2" },
    // CONUS row 4 (north): 43.5°N–49.5°N
    { minLat: 43.5, maxLat: 49.5, minLon: -125, maxLon: -110.4, label: "US-NW1" },
    { minLat: 43.5, maxLat: 49.5, minLon: -110.4, maxLon: -95.7, label: "US-NW2" },
    { minLat: 43.5, maxLat: 49.5, minLon: -95.7, maxLon: -81.1, label: "US-NE1" },
    { minLat: 43.5, maxLat: 49.5, minLon: -81.1, maxLon: -66.5, label: "US-NE2" },
    // Alaska + Hawaii
    { minLat: 51.0, maxLat: 72.0, minLon: -180, maxLon: -130, label: "US-AK" },
    { minLat: 18.5, maxLat: 22.5, minLon: -161, maxLon: -154, label: "US-HI" },
  ],
};

interface OCMConnection {
  ConnectionTypeID?: number;
  ConnectionType?: { Title?: string; FormalName?: string };
  PowerKW?: number | null;
  Quantity?: number | null;
  CurrentTypeID?: number;
  LevelID?: number;
}

interface OCMAddressInfo {
  Title?: string;
  AddressLine1?: string;
  Town?: string;
  StateOrProvince?: string;
  Postcode?: string;
  Latitude?: number;
  Longitude?: number;
}

interface OCMOperator {
  Title?: string;
}

interface OCMStatusType {
  IsOperational?: boolean;
}

interface OCMPoi {
  ID?: number;
  UUID?: string;
  AddressInfo?: OCMAddressInfo;
  OperatorInfo?: OCMOperator;
  Connections?: OCMConnection[];
  NumberOfPoints?: number | null;
  StatusType?: OCMStatusType;
  UsageCost?: string | null;
}

function ocmCountryCode(country: string): string {
  // Our internal codes already match ISO-3166 alpha-2, which is what OCM
  // accepts in its `countrycode` query parameter.
  return country;
}

async function fetchBoundingBox(
  countryCode: string,
  bbox: BBox,
  apiKey: string
): Promise<OCMPoi[]> {
  const url = new URL(API_URL);
  url.searchParams.set("countrycode", countryCode);
  url.searchParams.set("maxresults", String(PAGE_SIZE));
  // OCM accepts boundingbox as "(lat,lon),(lat,lon)" — bottom-left, top-right.
  url.searchParams.set(
    "boundingbox",
    `(${bbox.minLat},${bbox.minLon}),(${bbox.maxLat},${bbox.maxLon})`
  );
  url.searchParams.set("compact", "true");
  url.searchParams.set("verbose", "false");
  url.searchParams.set("output", "json");

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 60_000);

  let response: Response;
  try {
    response = await fetch(url.toString(), {
      headers: {
        "X-API-Key": apiKey,
        Accept: "application/json",
        "User-Agent": "GasolinaSmart-Backend/1.0",
      },
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    throw new Error(`OpenChargeMap API returned ${response.status}`);
  }

  return (await response.json()) as OCMPoi[];
}

function mapPoi(poi: OCMPoi, country: string): ChargingStationInput | null {
  const addr = poi.AddressInfo;
  if (!addr || addr.Latitude == null || addr.Longitude == null) return null;

  // OCM IDs are integers; prefix to keep our key-space consistent with fuel
  // stations and to avoid collisions across data sources.
  const id = `EV_${country}_${poi.ID ?? poi.UUID ?? ""}`;
  if (id === `EV_${country}_`) return null;

  const connections: ChargingConnectionInput[] = (poi.Connections ?? [])
    .map((c) => {
      const typeName = c.ConnectionType?.Title || c.ConnectionType?.FormalName;
      if (!typeName) return null;
      return {
        typeName,
        powerKW: typeof c.PowerKW === "number" ? c.PowerKW : null,
        quantity: typeof c.Quantity === "number" ? c.Quantity : null,
      };
    })
    .filter((c): c is ChargingConnectionInput => c !== null);

  const addressLines: string[] = [];
  if (addr.AddressLine1) addressLines.push(addr.AddressLine1);
  if (addr.Postcode) addressLines.push(addr.Postcode);

  return {
    id,
    name: addr.Title || poi.OperatorInfo?.Title || "Punto de carga",
    operatorName: poi.OperatorInfo?.Title ?? null,
    address: addressLines.join(" · "),
    municipality: addr.Town ?? "",
    province: addr.StateOrProvince ?? "",
    latitude: addr.Latitude,
    longitude: addr.Longitude,
    numberOfPoints: Math.max(poi.NumberOfPoints ?? 1, 1),
    isOperational: poi.StatusType?.IsOperational ?? true,
    usageCost: poi.UsageCost && poi.UsageCost.trim().length > 0 ? poi.UsageCost : null,
    connections,
  };
}

export async function fetchOpenChargeMap(
  db: D1Database,
  country: string,
  apiKey: string | undefined
): Promise<{ count: number; duration: number }> {
  if (!apiKey) {
    throw new Error("PAUSED: OPENCHARGEMAP_API_KEY not set");
  }

  const start = Date.now();
  const code = ocmCountryCode(country);
  console.log(`[fetcher:EV:${country}] Starting OpenChargeMap fetch (country=${code})...`);

  const seen = new Set<string>();
  const stations: ChargingStationInput[] = [];

  const bboxes = COUNTRY_BBOXES[code];
  if (!bboxes) {
    throw new Error(`No bounding boxes defined for country ${code}`);
  }

  for (const bbox of bboxes) {
    const pois = await fetchBoundingBox(code, bbox, apiKey);
    console.log(`[fetcher:EV:${country}] ${bbox.label}: +${pois.length} raw POIs`);

    let added = 0;
    for (const poi of pois) {
      const mapped = mapPoi(poi, country);
      if (!mapped) continue;
      if (seen.has(mapped.id)) continue;
      seen.add(mapped.id);
      stations.push(mapped);
      added++;
    }
    console.log(`[fetcher:EV:${country}] ${bbox.label}: +${added} new (deduped)`);
  }

  if (stations.length > 0) {
    await saveChargingStations(db, country, stations);
  }

  const duration = Date.now() - start;
  console.log(`[fetcher:EV:${country}] Saved ${stations.length} stations in ${duration}ms`);
  return { count: stations.length, duration };
}

export async function shouldFetchChargingStations(
  db: D1Database,
  country: string,
  intervalMinutes: number
): Promise<boolean> {
  const last = await getCountryMetaValue(db, country, "charging_last_fetch");
  if (!last) return true;
  const elapsed = Date.now() - new Date(last).getTime();
  return elapsed > intervalMinutes * 60 * 1000;
}
