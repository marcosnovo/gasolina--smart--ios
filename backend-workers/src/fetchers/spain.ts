import { saveStations, getCountryMetaValue } from "../database";
import type { StationInput } from "../database";

const MINISTERIO_URL =
  "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/";

const FUEL_FIELDS: Record<string, string> = {
  gasolina95: "Precio Gasolina 95 E5",
  gasolina98: "Precio Gasolina 98 E5",
  dieselA: "Precio Gasoleo A",
  dieselPremium: "Precio Gasoleo Premium",
  glp: "Precio Gases licuados del petróleo",
};

function parseSpanishDecimal(str: string): number | null {
  const cleaned = str.replace(/\./g, "").replace(",", ".").trim();
  const num = parseFloat(cleaned);
  return isNaN(num) ? null : num;
}

function parseSourceDate(dateStr?: string): string {
  if (!dateStr) return new Date().toISOString();
  const parts = dateStr.match(/(\d{2})\/(\d{2})\/(\d{4})\s+(\d{2}):(\d{2}):(\d{2})/);
  if (!parts) return new Date().toISOString();
  const [, day, month, year, hour, min, sec] = parts;
  return new Date(`${year}-${month}-${day}T${hour}:${min}:${sec}`).toISOString();
}

export async function fetchSpain(db: D1Database): Promise<{ count: number; duration: number }> {
  const start = Date.now();
  console.log("[fetcher:ES] Starting fetch from Ministerio API...");

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30_000);

  let response: Response;
  try {
    response = await fetch(MINISTERIO_URL, {
      headers: { Accept: "application/json" },
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    throw new Error(`Ministerio API returned ${response.status}`);
  }

  const json = (await response.json()) as {
    Fecha?: string;
    ListaEESSPrecio?: Array<Record<string, string>>;
  };

  const lista = json.ListaEESSPrecio;
  if (!lista || !Array.isArray(lista)) {
    throw new Error("Invalid response: no ListaEESSPrecio");
  }

  const sourceDate = parseSourceDate(json.Fecha);

  const stations: StationInput[] = [];

  for (const raw of lista) {
    const id = raw["IDEESS"];
    const latStr = raw["Latitud"];
    const lonStr = raw["Longitud (WGS84)"];

    if (!id || !latStr || !lonStr) continue;

    const lat = parseSpanishDecimal(latStr);
    const lon = parseSpanishDecimal(lonStr);

    if (lat == null || lon == null) continue;
    if (lat < 27 || lat > 44 || lon < -19 || lon > 5) continue;

    const prices: Record<string, number> = {};
    for (const [fuelType, fieldName] of Object.entries(FUEL_FIELDS)) {
      const priceStr = raw[fieldName];
      if (!priceStr || priceStr.trim() === "") continue;
      const price = parseSpanishDecimal(priceStr);
      if (price != null && price > 0) {
        prices[fuelType] = Math.round(price * 1000) / 1000;
      }
    }

    if (Object.keys(prices).length === 0) continue;

    stations.push({
      id: `ES_${id}`,
      name: (raw["Rótulo"] || "Estación").trim(),
      brand: (raw["Rótulo"] || "").trim(),
      address: (raw["Dirección"] || "").trim(),
      municipality: (raw["Municipio"] || "").trim(),
      province: (raw["Provincia"] || "").trim(),
      latitude: lat,
      longitude: lon,
      prices,
      updatedAt: sourceDate,
    });
  }

  await saveStations(db, "ES", stations);

  const duration = Date.now() - start;
  console.log(`[fetcher:ES] Saved ${stations.length} stations in ${duration}ms`);

  return { count: stations.length, duration };
}

export async function shouldFetchSpain(db: D1Database, intervalMinutes: number): Promise<boolean> {
  const last = await getCountryMetaValue(db, "ES", "last_fetch");
  if (!last) return true;
  const elapsed = Date.now() - new Date(last).getTime();
  return elapsed > intervalMinutes * 60 * 1000;
}
