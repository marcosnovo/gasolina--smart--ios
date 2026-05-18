import { Hono } from "hono";
import { cors } from "hono/cors";

export interface Env {
  DB: D1Database;
  SNAPSHOTS: R2Bucket;
  TANKERKOENIG_API_KEY?: string;
}

const app = new Hono<{ Bindings: Env }>();

app.use("/*", cors());

// --- Health ---

app.get("/health", (c) =>
  c.json({ status: "ok", timestamp: new Date().toISOString() })
);

// Phase 1 scaffolding — endpoints below are stubs to be implemented in later phases.

app.get("/api/health", (c) =>
  c.json({ ok: true, phase: 1, note: "scaffolding only — endpoints land in Phase 3" })
);

export default app;
