# Gasolina Smart — Cloudflare Workers backend

Migration of the Bun + SQLite backend to Cloudflare Workers + D1 + R2.

## Stack

- **Hono** — same web framework as before, works natively on Workers
- **D1** — Cloudflare's serverless SQLite (replaces `bun:sqlite`)
- **R2** — object storage for per-country station snapshots
- **Cron Triggers** — replace the `setInterval` cron loop

## Free-tier limits to keep in mind

| Resource | Limit | Notes |
|---|---|---|
| Workers requests | 100k / day | per zone, plenty for the iOS app |
| D1 reads | 5M rows / day | reads from query results |
| D1 writes | 100k rows / day | upserts + history inserts can add up — see below |
| R2 storage | 10 GB | one JSON snapshot per country (~1–5 MB each) |
| R2 ops | 1M Class A + 10M Class B / mo | reads cost almost nothing |
| Cron Triggers | unlimited on paid, limited on free | check current plan |

**Strategy to stay under D1 write limits**:
- `price_history` will only insert when a station's price for a fuel actually changes (deduped against the previous fetch).
- Current snapshots will be stored as JSON in **R2** instead of upserting every station/price on every fetch — only price-history goes to D1.

## One-time setup (run by the account owner)

```bash
# 1. Install deps
cd backend-workers
npm install

# 2. Authenticate
npx wrangler login

# 3. Create the D1 database
npm run db:create
# → copy the printed `database_id` into wrangler.toml (replace REPLACE_WITH_D1_ID)

# 4. Apply the schema to the remote D1
npm run db:migrate

# 5. Create the R2 bucket
npm run r2:create

# 6. (Phase 5+) Set the Germany API key as a secret
npx wrangler secret put TANKERKOENIG_API_KEY
# → paste your key when prompted

# 7. Deploy
npm run deploy
```

After deploy, Wrangler prints a URL like:
`https://gasolina-smart-api.<your-subdomain>.workers.dev`

That URL replaces your Railway base URL in the iOS app (see Phase 6).

## Local development

```bash
# Run the worker locally with a local D1 + R2
npm run db:migrate-local
npm run dev
# → http://localhost:8787
```

## Migration phases

| Phase | What lands | Status |
|---|---|---|
| 1 | Scaffolding: wrangler config, schema, Hono base, this README | ✅ this commit |
| 2 | D1 data layer (queries + writes) | pending |
| 3 | Read endpoints (`/api/stations`, `/api/stations/cheapest`, `/api/stations/:id`, `/api/history/:stationId`, `/api/countries`, `/api/meta`, `/api/health`) | pending |
| 4 | Fetchers: Spain + France + manual trigger `POST /api/fetch?country=…` | pending |
| 5 | Fetchers: UK + Germany + Italy | pending |
| 6 | Cron triggers + cutover (update iOS `BackendAPIService` base URL) | pending |

The existing `backend/` (Railway) keeps running until Phase 6. We only switch the iOS client over once Workers is verified.

## Project layout

```
backend-workers/
├── wrangler.toml      # Workers config, D1/R2 bindings, future cron triggers
├── package.json       # wrangler + hono + typescript
├── tsconfig.json
├── schema.sql         # D1 schema (apply with `npm run db:migrate`)
└── src/
    └── index.ts       # Hono app entry point
```
