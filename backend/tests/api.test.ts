import { describe, expect, test } from "bun:test";

const BASE = process.env.API_URL || "http://localhost:3000";

describe("GET /api/stations", () => {
  test("returns stations filtered by country", async () => {
    const res = await fetch(`${BASE}/api/stations?country=IT&lat=41.9&lon=12.5&radius=5&limit=5`);
    expect(res.status).toBe(200);

    const data = await res.json();
    for (const s of data.stations) {
      expect(s.id.startsWith("IT_")).toBe(true);
    }
  });

  test("defaults to ES when country param missing", async () => {
    const res = await fetch(`${BASE}/api/stations?lat=40.4&lon=-3.7&radius=5&limit=5`);
    expect(res.status).toBe(200);

    const data = await res.json();
    for (const s of data.stations) {
      expect(s.id.startsWith("ES_")).toBe(true);
    }
  });

  test("returns 400 when lat/lon missing", async () => {
    const res = await fetch(`${BASE}/api/stations?country=IT`);
    expect(res.status).toBe(400);
  });
});

describe("GET /api/stations/cheapest", () => {
  test("returns a station for Italy", async () => {
    const res = await fetch(`${BASE}/api/stations/cheapest?country=IT&lat=41.9&lon=12.5&radius=10&fuel=e5`);
    expect(res.status).toBe(200);

    const data = await res.json();
    if (data.station) {
      expect(data.station.id.startsWith("IT_")).toBe(true);
      expect(data.station.prices.e5).toBeGreaterThan(0);
    }
  });
});

describe("GET /api/health", () => {
  test("returns status for all countries", async () => {
    const res = await fetch(`${BASE}/api/health`);
    expect(res.status).toBe(200);

    const data = await res.json();
    expect(data.ok).toBe(true);
    expect(data.countries.IT).toBeDefined();
    expect(data.countries.ES).toBeDefined();
    expect(data.countries.FR).toBeDefined();
  });
});
