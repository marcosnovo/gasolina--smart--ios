import { describe, expect, test } from "bun:test";
import { parseFranceRecords, type FranceRecord } from "../src/fetchers/france";

function makeRecord(overrides: Partial<FranceRecord> = {}): FranceRecord {
  return {
    id: 75001,
    adresse: "1 Rue de Rivoli",
    ville: "Paris",
    cp: "75001",
    departement: "Paris",
    geom: { lat: 48.8566, lon: 2.3522 },
    gazole_prix: 1.789,
    gazole_maj: "2026-05-13T08:00:00+02:00",
    sp95_prix: 1.859,
    sp95_maj: "2026-05-13T08:00:00+02:00",
    sp98_prix: 1.959,
    sp98_maj: "2026-05-13T08:00:00+02:00",
    e10_prix: 1.819,
    e10_maj: "2026-05-13T08:00:00+02:00",
    e85_prix: 0.849,
    e85_maj: "2026-05-13T08:00:00+02:00",
    gplc_prix: 0.969,
    gplc_maj: "2026-05-13T08:00:00+02:00",
    ...overrides,
  };
}

describe("France parser", () => {
  test("validRecordsAreInserted", () => {
    const records = [
      makeRecord({ id: 1 }),
      makeRecord({ id: 2, ville: "Lyon", geom: { lat: 45.7640, lon: 4.8357 } }),
    ];

    const result = parseFranceRecords(records);
    expect(result.stations.length).toBe(2);
    expect(result.skippedNoGeo).toBe(0);
    expect(result.skippedNoPrices).toBe(0);
    expect(result.skippedOutOfBounds).toBe(0);

    expect(result.stations[0].id).toBe("FR_1");
    expect(result.stations[0].latitude).toBe(48.8566);
    expect(result.stations[0].prices["dieselA"]).toBe(1.789);
    expect(result.stations[0].prices["e5"]).toBe(1.859);
    expect(result.stations[0].prices["e10"]).toBe(1.819);
  });

  test("recordsWithoutGeomAreFiltered", () => {
    const records = [
      makeRecord({ id: 1 }),
      makeRecord({ id: 2, geom: undefined }),
      makeRecord({ id: 3, geom: { lat: NaN, lon: 2.35 } }),
    ];

    const result = parseFranceRecords(records);
    expect(result.stations.length).toBe(1);
    expect(result.skippedNoGeo).toBe(2);
  });

  test("fuelTypeMappingIsCorrect", () => {
    const record = makeRecord();
    const result = parseFranceRecords([record]);
    const prices = result.stations[0].prices;

    expect(prices["dieselA"]).toBe(1.789);
    expect(prices["e5"]).toBe(1.859);
    expect(prices["gasolina98"]).toBe(1.959);
    expect(prices["e10"]).toBe(1.819);
    expect(prices["e85"]).toBe(0.849);
    expect(prices["glp"]).toBe(0.969);
  });

  test("recordsWithNoPricesAreFiltered", () => {
    const records = [
      makeRecord({
        id: 1,
        gazole_prix: null,
        sp95_prix: null,
        sp98_prix: null,
        e10_prix: null,
        e85_prix: null,
        gplc_prix: null,
      }),
      makeRecord({
        id: 2,
        gazole_prix: 0,
        sp95_prix: 0,
        sp98_prix: 0,
        e10_prix: 0,
        e85_prix: 0,
        gplc_prix: 0,
      }),
    ];

    const result = parseFranceRecords(records);
    expect(result.stations.length).toBe(0);
    expect(result.skippedNoPrices).toBe(2);
  });

  test("outOfBoundsRecordsAreFiltered", () => {
    const records = [
      makeRecord({ id: 1, geom: { lat: 60.0, lon: 2.0 } }),
      makeRecord({ id: 2, geom: { lat: 48.8, lon: 2.3 } }),
    ];

    const result = parseFranceRecords(records);
    expect(result.stations.length).toBe(1);
    expect(result.skippedOutOfBounds).toBe(1);
  });
});
