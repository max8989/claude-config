# Stack & libraries

The versions below are the **known-good baseline** this pattern was proven on.
They are a floor, not a pin: before running `npm install`, resolve the current
major with Context7 (`resolve-library-id` → `query-docs`) for anything you'll
write non-trivial code against — Ionic, Vite, vite-plugin-pwa, TanStack Query,
Fastify, and the PocketBase JS SDK all shift APIs across majors. Pin the
PocketBase **server** release in `pocketbase/Dockerfile` to a real tag from the
releases page.

## Frontend

| Library | Baseline | Role |
|---|---|---|
| `react` / `react-dom` | ^18.3 | UI |
| `@ionic/react` + `@ionic/react-router` | ^8 | Mobile-grade component kit + native-feeling routing/transitions. Provides the tab shell, sliding rows, modals, toasts, dark palette. |
| `ionicons` | ^7 | Icon set that ships with Ionic |
| `react-router` / `react-router-dom` | compatible with Ionic | Match the router major to the installed `@ionic/react-router` major and verify its current API before generating routes; do not inherit a stale pin. |
| `vite` + `@vitejs/plugin-react` | ^5 / ^4 | Build tool + dev server |
| `vite-plugin-pwa` | ^0.20 | Manifest + service-worker wiring. Use `injectManifest` so the SW is our own `src/sw.ts` (needed for Web Push). |
| `workbox-core` / `workbox-precaching` | ^7 | Precache + `clientsClaim` inside the SW |
| `@tanstack/react-query` | ^5 | Server-state cache: queries, optimistic mutations, invalidation |
| `pocketbase` (JS SDK) | ^0.26 | **Auth only** on the client (`authWithPassword`, `authStore`) |
| `vitest` + `jsdom` + Testing Library | current compatible | Component tests for interaction, routing, confirmation, and state boundaries |
| `@playwright/test` + `@axe-core/playwright` | current compatible | WebKit mobile viewport, screenshot, overflow, and accessibility regression checks |

Fonts: default to the platform system stack for native rendering and reliable
offline launch. If the user chooses branded fonts, prefer bundled/self-hosted
files. Use external font hosts only when explicitly requested, with robust
fallbacks and an offline/cold-start check.

## API

| Library | Baseline | Role |
|---|---|---|
| `fastify` | ^5 | HTTP server |
| `@fastify/static` | ^8 | Serves the built SPA in production |
| `pocketbase` (JS SDK) | ^0.26 | Superuser data client + per-request token validation |
| `tsx` | ^4 | Runs the TypeScript directly — **no build step**, `tsx src/index.ts` |
| `node-cron` | ^3 | In-process schedules (generation, overdue flags, notification ticks) |
| `web-push` | ^3 | Sends Web Push (VAPID) — the reason a Node process exists at all |
| `vitest` | ^2 | Tests, against an in-memory fake PocketBase |

## Data

- **PocketBase** (single Go binary) — database (SQLite), auth, file storage,
  admin UI, JS migrations. Pinned via `ARG PB_VERSION` in its Dockerfile.
- Schema lives in `pocketbase/pb_migrations/*.js` (schema as code). Migrations
  run at boot; the field/collection JS API changes across PB versions, so check
  the generated `pb_data/types.d.ts` and the migration guide for the pinned
  version.

## Orchestration

- One `docker-compose.yml`: `pocketbase` (private), `api` (only exposed
  service), `frontend-build` (one-shot, compiles SPA into a shared volume).
- `tzdata` is installed in the Node and PocketBase images and `TZ` is set —
  crons and local-date math break silently on UTC otherwise.
