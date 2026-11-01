# Architecture

A self-hosted, installable PWA with a Node API in front of PocketBase. Runs as
one `docker compose` stack. No reverse proxy / TLS is part of the stack — front
it with whatever the host already runs (nginx proxy manager, Traefik, a
platform ingress). HTTPS is mandatory in production: service workers and Web
Push refuse to run on insecure origins.

## Repo layout

```
<app>/
  docker-compose.yml       # pocketbase (private) + api (exposed) + frontend-build (one-shot)
  .env.example             # admin creds, VAPID keys, ports, TZ
  frontend/                # React + Vite + Ionic React PWA
    index.html
    vite.config.ts         # vite-plugin-pwa, manifest, manualChunks, dev proxy
    tsconfig.json
    Dockerfile
    public/                # icon-192.png, icon-512.png, icon.svg
    src/
      main.tsx             # mounts <App>, imports Ionic CSS + dark palette + theme/variables.css, initTheme()
      App.tsx              # IonApp, QueryClientProvider, AuthProvider, tabs, SSE stream, auth gate
      sw.ts                # custom service worker (Workbox precache + push handlers)
      theme/variables.css  # design tokens: light :root + .ion-palette-dark, component styles
      lib/                 # pb, api, queryClient, queries, mutations, theme, haptics, toast, push, types
      auth/AuthContext.tsx # authStore-backed React context
      components/          # GlobalLoadingBar, ReloadPrompt, Skeletons, ...
      pages/              # one IonPage per route
  api/                     # Fastify (TypeScript, run with tsx — no build step)
    tsconfig.json
    Dockerfile
    src/
      index.ts             # wires Deps, builds server, starts crons
      server.ts            # Fastify instance, error handler, /api/health, route registration, SPA fallback
      env.ts               # required()/optional env parsing
      deps.ts              # Deps type (dependency injection seam for tests)
      pb.ts                # superuser client + per-request token validation
      auth.ts              # requireUser / requireAdmin preHandlers
      routes/              # one register<Name>(app, deps, requireUser) per resource
      domain/              # pure business logic (no Fastify types) — unit-testable
      push.ts, notify.ts, crons.ts, audit.ts
    test/                  # vitest, with an in-memory fake PocketBase
  pocketbase/
    Dockerfile             # downloads a pinned PocketBase release
    pb_migrations/         # JS migrations (schema as code)
    pb_data/               # runtime data (gitignored)
```

## The one rule that shapes everything: the API fronts PocketBase

The PWA frontend talks to the Node API for application data. The API holds a
long-lived **superuser** PocketBase client and performs application reads/writes;
PocketBase collection rules stay locked down. The built-in PocketBase dashboard
is a separate operator interface at `https://<app-domain>/_/`, proxied through
the same Node API with the operator's own superuser credentials.

The frontend's PocketBase client (`lib/pb.ts`) is **auth-only** —
`new PocketBase("/")`. It uses the selected `authWithPassword` or `authWithOTP`
method, `authRefresh`, and `authStore` for the session. Everything else goes through
`lib/api.ts`, a typed `fetch` wrapper that attaches the bearer token. That
client also owns the session lifecycle — expiry detection and the sliding
`authRefresh` — see `patterns.md` §6, worth reading before writing either file.

Why this shape:
- **One trust boundary.** Business rules, validation, and authorization live in
  the API, not spread across PocketBase collection rules.
- **Web Push needs a real Node runtime.** `web-push` can't run inside
  PocketBase's JS VM, so a Node process is required anyway — make it the front.
- **The API serves the SPA too.** In production the built frontend is served by
  Fastify (`@fastify/static`) from a shared Docker volume, so there is a single
  exposed origin and same-origin cookies/tokens just work.

### Request flow

```
Browser ──/api/collections/users/auth-*──▶ API ──(streamed passthrough)──▶ PocketBase   (login/refresh only)
Browser ──POST /api/auth/email/request──▶ API ──(guarded OTP request)──▶ PocketBase   (email-otp mode only)
Browser ──/api/<resource> (Bearer token)─▶ API ──(superuser client)──────▶ PocketBase   (all data)
Browser ──/api/events?token=… (EventSource)▶ API  (SSE; in-process event bus fan-out)
Operator ──/_/ + management API─────────▶ API ──(operator credentials)─▶ PocketBase dashboard/API
Browser ──GET / , /home , …───────────────▶ API ──(static)──────────────▶ built SPA (index.html fallback)
```

Implement the selected sign-in routes explicitly using
[the authentication contract](authentication.md); the diagram's `auth-*` is
shorthand, not a wildcard allowlist. OTP verification needs its guards before
upstream forwarding, and OTP requests must go through the app's request route.
For ordinary app clients, proxy only selected user login/refresh and read-only
`/api/files/*` (so avatars load with PocketBase off the public network).
Also serve the dashboard and its superuser authentication/management APIs
according to [the dashboard contract](pocketbase-admin.md). Reject unauthorized
raw collection access and unknown API routes; preserve explicit app routes.
Public dashboard access uses the app origin, not the private PocketBase port.

## Dev vs. production

- **Dev:** run PocketBase (compose) + `npm run dev` in `frontend/` (Vite on
  5173, proxies `/api` and `/_` → `:3000`) + `npm run dev` in `api/` (tsx watch on 3000).
  Web Push won't work on `http://localhost` in iOS Safari; test the subscribe
  flow on desktop Chrome and end-to-end push on an installed HTTPS build.
- **Prod:** `docker compose up -d --build`. `frontend-build` compiles the SPA
  into a volume; `api` serves it. Create the PocketBase superuser on first run
  (`pocketbase superuser upsert`), then add users in the admin UI.

See `patterns.md` for the conventions and `features.md` for what each optional
feature adds.
