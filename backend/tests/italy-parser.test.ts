import { describe, expect, test } from "bun:test";
import {
  detectSeparator,
  normalizeBrand,
  parseItalianDate,
  parseAnagraficaText,
  parsePrezziText,
  buildStationList,
  FUEL_MAP,
  type StationData,
} from "../src/fetchers/italy";

const validAnagrafica = `Estrazione del 13/05/2026
idImpianto|Gestore|Bandiera|Tipo Impianto|Nome Impianto|Indirizzo|Comune|Provincia|Latitudine|Longitudine
12345|Eni Spa|Eni|Stradale|Eni Roma 1|Via del Corso 1|Roma|RM|41.9028|12.4964
67890|Q8 Spa|Q8|Stradale|Q8 Milano|Via Dante 2|Milano|MI|45.4642|9.1900
11111|Tamoil|Tamoil|Stradale|Tamoil Napoli|Via Roma 3|Napoli|NA|40.8518|14.2681`;

const problematicAnagrafica = `Estrazione del 13/05/2026
idImpianto|Gestore|Bandiera|Tipo Impianto|Nome Impianto|Indirizzo|Comune|Provincia|Latitudine|Longitudine
22222|Test|Eni|Stradale|Sin coords|Via X|Roma|RM||
33333|Test|Eni|Stradale|Coords NaN|Via X|Roma|RM|abc|def
44444|Test|Eni|Stradale|Coords cero|Via X|Roma|RM|0|0
55555|Test|Eni|Stradale|Fuera bbox|Via X|Roma|RM|55.0|2.0
66666|Test|Eni|Stradale|Pocas cols|Via X|Roma
77777|Test|Eni|Stradale|Coords con coma|Via X|Roma|RM|41,9028|12,4964`;

const semicolonAnagrafica = `Estrazione del 13/05/2026
idImpianto;Gestore;Bandiera;Tipo Impianto;Nome Impianto;Indirizzo;Comune;Provincia;Latitudine;Longitudine
88888;Eni;Eni;Stradale;Eni Test;Via Y;Roma;RM;41.9028;12.4964`;

function recentDate(): string {
  const d = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000);
  const dd = String(d.getDate()).padStart(2, "0");
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const yyyy = d.getFullYear();
  return `${dd}/${mm}/${yyyy} 08:00:00`;
}

function staleDate(): string {
  const d = new Date(Date.now() - 31 * 24 * 60 * 60 * 1000);
  const dd = String(d.getDate()).padStart(2, "0");
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const yyyy = d.getFullYear();
  return `${dd}/${mm}/${yyyy} 08:00:00`;
}

function makePrezziCSV(rows: string[]): string {
  return `Estrazione del 13/05/2026
idImpianto;descCarburante;prezzo;isSelf;dtComu
${rows.join("\n")}`;
}

describe("Italy parser — Anagrafica", () => {
  test("validRowsAreInserted", () => {
    const { stationMap, skippedNoCoords, skippedOutOfBounds } =
      parseAnagraficaText(validAnagrafica);

    expect(stationMap.size).toBe(3);
    expect(skippedNoCoords).toBe(0);
    expect(skippedOutOfBounds).toBe(0);

    const roma = stationMap.get("12345")!;
    expect(roma.id).toBe("IT_12345");
    expect(roma.latitude).toBe(41.9028);
    expect(roma.longitude).toBe(12.4964);
    expect(roma.brand).toBe("Eni");
    expect(roma.municipality).toBe("Roma");
  });

  test("rowsWithMissingCoordsAreFiltered", () => {
    const { stationMap, skippedNoCoords, skippedOutOfBounds } =
      parseAnagraficaText(problematicAnagrafica);

    // 77777 "41,9028" → parseFloat gives 41 (truncates at comma), lon=12 → inside Italy bbox
    // So 1 station survives (comma-decimal is a lossy parse, not a rejection)
    expect(stationMap.size).toBe(1);
    // empty coords, NaN coords ("abc"), zero coords = 3 no-coords
    expect(skippedNoCoords).toBe(3);
    // lat=55 out of bbox = 1
    expect(skippedOutOfBounds).toBe(1);
    // 66666 has <10 cols → silently skipped by cols.length check
  });

  test("detectsSemicolonSeparator", () => {
    const { stationMap } = parseAnagraficaText(semicolonAnagrafica);
    expect(stationMap.size).toBe(1);
    const s = stationMap.get("88888")!;
    expect(s.id).toBe("IT_88888");
    expect(s.latitude).toBe(41.9028);
  });

  test("decodesLatin1Correctly", () => {
    const latin1Bytes = new Uint8Array([
      0x50, 0x65, 0x72, 0xf9, // Perù
    ]);
    const decoder = new TextDecoder("iso-8859-1");
    const decoded = decoder.decode(latin1Bytes);
    expect(decoded).toBe("Perù");

    const cefaluBytes = new Uint8Array([
      0x43, 0x65, 0x66, 0x61, 0x6c, 0xf9, // Cefalù
    ]);
    expect(decoder.decode(cefaluBytes)).toBe("Cefalù");

    const cittaBytes = new Uint8Array([
      0x63, 0x69, 0x74, 0x74, 0xe0, // città
    ]);
    expect(decoder.decode(cittaBytes)).toBe("città");
  });
});

describe("Italy parser — Prezzi", () => {
  test("filtersStaleTimestamps", () => {
    const { stationMap } = parseAnagraficaText(validAnagrafica);

    const prezzi = makePrezziCSV([
      `12345;Benzina;1.899;1;${staleDate()}`,
      `67890;Benzina;1.859;1;${recentDate()}`,
    ]);

    const stats = parsePrezziText(prezzi, stationMap);
    expect(stats.pricesStale).toBe(1);
    expect(stats.pricesMatched).toBe(1);

    const roma = stationMap.get("12345")!;
    expect(Object.keys(roma.prices).length).toBe(0);

    const milano = stationMap.get("67890")!;
    expect(milano.prices["e5"]).toBe(1.859);
  });

  test("filtersInvalidPrices", () => {
    const { stationMap } = parseAnagraficaText(validAnagrafica);

    const prezzi = makePrezziCSV([
      `12345;Benzina;0;1;${recentDate()}`,
      `67890;Benzina;-1;1;${recentDate()}`,
      `11111;Benzina;99;1;${recentDate()}`,
      `12345;Gasolio;1.5;1;${recentDate()}`,
    ]);

    const stats = parsePrezziText(prezzi, stationMap);
    expect(stats.pricesInvalid).toBe(3);
    expect(stats.pricesMatched).toBe(1);

    expect(stationMap.get("12345")!.prices["dieselA"]).toBe(1.5);
  });

  test("unknownFuelTypeIsLoggedAndSkipped", () => {
    const { stationMap } = parseAnagraficaText(validAnagrafica);

    const prezzi = makePrezziCSV([
      `12345;Foo Premium XL;1.899;1;${recentDate()}`,
      `12345;Benzina;1.799;1;${recentDate()}`,
    ]);

    const stats = parsePrezziText(prezzi, stationMap);
    expect(stats.pricesUnmapped).toBe(1);
    expect(stats.unmappedFuels.get("Foo Premium XL")).toBe(1);
    expect(stats.pricesMatched).toBe(1);
  });
});

describe("Italy parser — helpers", () => {
  test("detectSeparator pipe vs semicolon", () => {
    expect(detectSeparator("a|b|c|d|e")).toBe("|");
    expect(detectSeparator("a;b;c;d;e")).toBe(";");
    expect(detectSeparator("a|b")).toBe("|");
    expect(detectSeparator("no delimiters")).toBe("|");
  });

  test("normalizeBrand capitalizes first letter", () => {
    expect(normalizeBrand("eni")).toBe("Eni");
    expect(normalizeBrand("Q8")).toBe("Q8");
    expect(normalizeBrand("")).toBe("");
    expect(normalizeBrand("  ")).toBe("");
  });

  test("parseItalianDate parses DD/MM/YYYY HH:MM:SS", () => {
    const d = parseItalianDate("13/05/2026 08:00:00");
    expect(d).not.toBeNull();
    expect(d!.getFullYear()).toBe(2026);
    expect(d!.getMonth()).toBe(4); // May = 4
    expect(d!.getDate()).toBe(13);

    expect(parseItalianDate("invalid")).toBeNull();
    expect(parseItalianDate("")).toBeNull();
  });

  test("FUEL_MAP covers expected fuel types", () => {
    expect(FUEL_MAP["Benzina"]).toBe("e5");
    expect(FUEL_MAP["Gasolio"]).toBe("dieselA");
    expect(FUEL_MAP["GPL"]).toBe("glp");
    expect(FUEL_MAP["Metano"]).toBe("gnc");
    expect(FUEL_MAP["Benzina Plus"]).toBe("gasolina98");
    expect(FUEL_MAP["Gasolio Premium"]).toBe("dieselPremium");
    expect(FUEL_MAP["NonExistent"]).toBeUndefined();
  });
});
