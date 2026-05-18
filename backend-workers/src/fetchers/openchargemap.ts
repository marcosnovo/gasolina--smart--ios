import { saveChargingStations, getCountryMetaValue } from "../database";
import type { ChargingStationInput, ChargingConnectionInput } from "../database";

// OpenChargeMap is purpose-built for EV charging data and has connector-level
// detail that OpenStreetMap doesn't. The free API tier needs an API key
// registered at https://openchargemap.org/site/profile/applications and is set
// as the OPENCHARGEMAP_API_KEY worker secret.
const API_URL = "https://api.openchargemap.io/v3/poi/";

// OCM caps maxresults per call. We page through with `offset` since some
// countries (Spain, France, Germany) have well over 10k stations.
const PAGE_SIZE = 5000;
const MAX_PAGES = 6;

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

async function fetchOnePage(
  countryCode: string,
  offset: number,
  apiKey: string
): Promise<OCMPoi[]> {
  const url = new URL(API_URL);
  url.searchParams.set("countrycode", countryCode);
  url.searchParams.set("maxresults", String(PAGE_SIZE));
  url.searchParams.set("offset", String(offset));
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

  for (let page = 0; page < MAX_PAGES; page++) {
    const offset = page * PAGE_SIZE;
    const pois = await fetchOnePage(code, offset, apiKey);
    console.log(`[fetcher:EV:${country}] page ${page + 1}: +${pois.length} raw POIs`);
    if (pois.length === 0) break;

    for (const poi of pois) {
      const mapped = mapPoi(poi, country);
      if (!mapped) continue;
      if (seen.has(mapped.id)) continue;
      seen.add(mapped.id);
      stations.push(mapped);
    }

    if (pois.length < PAGE_SIZE) break;
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
