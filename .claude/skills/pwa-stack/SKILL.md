---
name: pwa-stack
description: >-
  Scaffold a new installable PWA backed by a self-hosted stack — React + Vite +
  Ionic React frontend (vite-plugin-pwa, custom service worker, Web Push),
  Fastify + TypeScript API in front of PocketBase, TanStack Query with
  optimistic mutations + toasts, CSS-token theming with light/dark, all wired
  as one docker-compose stack. Use this whenever the user wants to START a new
  mobile-first web app, PWA, installable app, or "app like roommate" with a
  backend/database/auth — even if they don't name the stack. Triggers:
  "new PWA", "scaffold an app", "create a mobile web app", "start a project
  with PocketBase/Ionic", "installable app with notifications", "spin up a
  frontend + backend + db". The skill asks about colors, dark mode, fonts, and
  which features (push, realtime, roles, iOS) before generating. NOT for adding
  a feature to an existing app of a different stack, or for pure static sites.
---

# pwa-stack

Scaffold a new project that reuses the architecture, libraries, and conventions
of the reference app: an installable PWA (React + Vite + Ionic React) served by
a Fastify/TypeScript API that fronts PocketBase, shipped as one `docker compose`
stack. This skill captures the **structure and patterns**, not a frozen copy of
the source — you generate current-API code that follows the documented
conventions, so it doesn't rot when Ionic/Vite/PocketBase ship new versions.

## What this skill contains

- `references/architecture.md` — repo layout, the "API fronts PocketBase" model,
  request flow, dev vs prod.
- `references/stack.md` — the libraries, their roles, and known-good baseline
  versions (a floor — confirm current majors before installing).
- `references/patterns.md` — the house conventions (auth-only client + `api()`,
  optimistic-mutation-then-toast, global loading bar, SSE invalidation, theme
  tokens, custom SW update flow, API DI/route shape, native touches).
- `references/theme-tokens.md` — the CSS-token system and how to derive a
  light/dark palette from the user's answers.
- `references/features.md` — what each optional feature adds/removes.
- `templates/` — the **stable** boilerplate worth copying verbatim (compose,
  Dockerfiles, vite PWA config, index.html, tsconfigs, init migration,
  `frontend/src/lib/install.ts`, `frontend/src/components/ConfirmModal.tsx`,
  `frontend/src/components/PageRefresher.tsx`). These carry `__PLACEHOLDER__`
  tokens and `[FEATURE: x]` markers.
- `scripts/make-icons.sh` — generates placeholder PWA icons from an accent
  colour + letters.

**Read `references/patterns.md` and `references/architecture.md` before
generating any code** — they define the conventions the generated app must
follow.

## Workflow

### 1. Gather requirements

First settle the app identity conversationally (ask only what wasn't given):
- **App name** and a lowercase **slug** (used for package names, dirs,
  `admin@<slug>.local`).
- One-line **description** (PWA manifest).
- **Accent / brand color** (hex). Ask for a second brand color only if they
  want one.
- **Target directory** (default: a new folder named after the slug).
- **Language** for `<html lang>` (default `en`).

Then ask the choice-based questions with **one `AskUserQuestion` call** (present
all four together):

1. **Surface tone** — `Warm` / `Cool` / `Neutral` (drives the greys behind the
   accent).
2. **Dark mode** — `Both light + dark (recommended)` / `Light only` /
   `Dark only`.
3. **Fonts** — `Bricolage Grotesque + Figtree (baseline)` / `System fonts` /
   `Custom (they name them)`.
4. **Features** (multi-select) — `Web Push notifications` / `Realtime (SSE)` /
   `Roles + admin screen` / `iOS install tuning`. See `references/features.md`.

If the user already stated any of these, skip that question.

### 2. Confirm current library versions

For each major dependency you'll write non-trivial code against (Ionic React,
Vite, vite-plugin-pwa, TanStack Query, Fastify, PocketBase JS SDK) resolve the
current version and any API changes with Context7 (`resolve-library-id` →
`query-docs`). Pin the PocketBase **server** release (its Dockerfile `ARG
PB_VERSION`) to a real tag from the releases page. The baselines in
`stack.md` are a floor, not a pin.

### 3. Create the structure and copy stable templates

Create the repo layout from `architecture.md`. Copy the files under
`templates/` into place (mirrored paths: `templates/frontend/*` →
`<app>/frontend/`, `templates/api/Dockerfile` → `<app>/api/`,
`templates/pocketbase/*` → `<app>/pocketbase/`, `templates/docker-compose.yml`
and `templates/.env.example` → repo root). Then substitute the placeholders in
every copied file:

| Placeholder | Value |
|---|---|
| `__APP_NAME__` | display name |
| `__APP_SHORT_NAME__` | short name (≤12 chars, home-screen label) |
| `__APP_SLUG__` | lowercase slug |
| `__APP_DESC__` | one-line description |
| `__APP_LANG__` | html lang |
| `__ACCENT__` | accent hex |
| `__BG_LIGHT__` / `__BG_DARK__` | light/dark `--bg` (from the palette you derive) |
| `__FONT_LINK__` | Google Fonts `<link>` (or delete the line for system fonts) |

Also write `package.json` for `frontend/` and `api/` (not templated — generate
with the confirmed versions and the scripts from `stack.md`: frontend
`dev/build/preview`, api `dev` = `tsx watch src/index.ts`, `start` = `tsx
src/index.ts`, `typecheck`, `test`), plus `.gitignore` files (ignore
`node_modules`, `dist`, `pb_data`, `.env`).

### 4. Generate the theme

Following `references/theme-tokens.md`, derive the full token set from the
accent + surface tone + dark-mode choice and write
`frontend/src/theme/variables.css` (light `:root`, `.ion-palette-dark` unless
light-only, the `--ion-*` bridge, and the `ui-` component classes the pages
use). Keep `__BG_LIGHT__`/`__BG_DARK__` consistent across `variables.css`,
`index.html`, `lib/theme.ts`, and the manifest in `vite.config.ts`. Wire the
chosen fonts into `--ion-font-family`, the heading font, and `index.html`.

### 5. Generate the application code following the patterns

Write the frontend `src/` (main.tsx, App.tsx, sw.ts, vite-env.d.ts, the `lib/`
data+theme+ux helpers, `auth/AuthContext.tsx`, `components/`, and the example
pages) and the api `src/` (index, server, env, deps, pb, auth, routes/, domain/,
plus push/notify/crons if applicable) **to current library APIs**, following
every convention in `patterns.md`. Include exactly one example resource wired
end to end — a simple `items` list (title/notes/done/due_date/created_by) — so
the user sees the full read + optimistic-write + toast + invalidate loop and the
matching API route and migration collection. Do **not** invent extra domain
logic; the user replaces `items` with their own.

Only generate the code for the features that are ON (see `references/
features.md`); omit the `[FEATURE: x]` blocks for features that are OFF, and
leave the init migration / env / deps trimmed to match.

#### Automatic PWA updates (required)

Generated apps must apply new deployments automatically, without presenting an
update toast, modal, or confirmation button. Reproduce the update flow from the
reference app's commit `68333c015b9a5c0c02b2e7a1a8b57e3c9ca1d549`:

- In `vite.config.ts`, set `registerType: "autoUpdate"` and define a unique
  `__BUILD_VERSION__` for every build with
  `JSON.stringify(Date.now().toString())`. This makes the generated service
  worker differ even when the application assets are unchanged.
- In `src/sw.ts`, declare and reference `__BUILD_VERSION__` so it remains in the
  compiled worker, then call `self.skipWaiting()` unconditionally and use
  Workbox's `clientsClaim()`.
- Generate a headless `components/PwaAutoUpdate.tsx` that calls
  `useRegisterSW({ immediate: true })`, calls `registration.update()` every 60
  seconds, and checks again whenever `document.visibilityState` becomes
  `"visible"`. Render this component once near the root of `App.tsx`.
- Do not generate `ReloadPrompt`, `IonToast`, `needRefresh`, or any other
  user-controlled update UI. The `autoUpdate` registration must reload an open
  client as soon as the new worker activates.

#### In-app install button (required)

Every generated app must expose an explicit **Install app** button on its
settings/profile page — see `patterns.md` §11. Copy
`templates/frontend/src/lib/install.ts` verbatim to
`<app>/frontend/src/lib/install.ts`, call `initInstall()` in `main.tsx` before
`createRoot` (the event fires before any page mounts), and render the button
with `useInstallState()`: native `promptInstall()` when `canPrompt`, otherwise a
sheet with manual *Add to Home Screen* steps branching on `isIOS()`. Hide the
whole section when `installed` is true. Style the sheet with the app's own `ui-`
classes rather than importing another modal system.

Keep the build constant available to both Vite compilation targets. A minimal
configuration and worker setup is:

```ts
// vite.config.ts
define: {
  __BUILD_VERSION__: JSON.stringify(Date.now().toString()),
},
// inside VitePWA(...)
registerType: "autoUpdate",
```

```ts
// src/sw.ts
declare const __BUILD_VERSION__: string
console.info(`[SW] Build ${__BUILD_VERSION__}`)
self.skipWaiting()
clientsClaim()
```

#### Confirmation sheet for destructive actions (required)

No destructive action may fire straight from a tap — a misclick on a trash
icon must not delete data. Copy
`templates/frontend/src/components/ConfirmModal.tsx` verbatim, wrap the app
shell in `ConfirmProvider` (inside `IonApp`), and route **every** delete/remove
— including the "unsave" side of save toggles that lose server-side progress —
through `await confirm({...})` before mutating. Add the `ui-confirm-*` sheet
classes to `variables.css`. Wording, mechanics, and CSS: `patterns.md` §13.

#### Pull-to-refresh on tab-root pages (required)

Copy `templates/frontend/src/components/PageRefresher.tsx` verbatim and render
it as the first child of `IonContent` on every tab-root/list page, passing that
page's query-key families (e.g.
`<PageRefresher queryKeys={[keys.items]} />`). Details: `patterns.md` §14.

### 6. Icons

Run `scripts/make-icons.sh <app>/frontend/public "<accent>" "<contrast>"
"<1-2 letters>"` to write `icon.svg`, `icon-192.png`, `icon-512.png`. If no
SVG→PNG converter is installed it writes the SVG and warns — tell the user to
supply the PNGs (or real artwork) before shipping.

### 7. Verify and hand off

- Run `tsc --noEmit` (typecheck) in `frontend/` and `api/` if deps are
  installed; otherwise note that `npm install` is needed first.
- Print next steps: `cp .env.example .env` and fill it (generate VAPID keys with
  `npx web-push generate-vapid-keys` if push is on); `docker compose up -d
  --build`; create the PocketBase superuser
  (`docker compose exec pocketbase /pb/pocketbase superuser upsert <email>
  <password>`); open the PocketBase admin, add users with `active = true`; open
  the app on the API port. Remind them HTTPS (via their own reverse proxy) is
  required for service workers and Web Push in production, and that this stack
  intentionally does not include TLS/proxy.
- **Tell them the session length** — the init migration sets
  `users.authToken.duration` to 30 days and the client slides it forward on
  every app open (`patterns.md` §6), so a session ends only after 30 straight
  days away. Mention it so they can raise or lower it deliberately. Like the
  VAPID bug below, a mishandled expiry is invisible until the first token dies
  days after launch — and it surfaces as "the app shows empty pages until I log
  out and back in", not as anything that looks like auth.
- **If push is on, leave `VAPID_SUBJECT` as a real routable value** (an
  `https:` URL or a `mailto:` on a real domain). Do NOT substitute the `.local`
  admin email or any non-routable domain into it: Apple/iOS Web Push validates
  the JWT `sub` and rejects `.local`/`.invalid`/`.internal` with `403
  BadJwtToken`, silently dropping every push. Chrome/FCM accepts it, so the bug
  is invisible until an iPhone tries — it breaks ONLY iOS, ONLY in production.
- **iOS push testing caveat** (tell the user): Web Push on iOS 16.4+ works only
  from a PWA **installed to the Home Screen** (Safari → Share → Add to Home
  Screen), never a Safari tab, and only over HTTPS. FCM/Chrome succeeding does
  not prove iOS works — verify the end-to-end send against a real
  `web.push.apple.com` subscription and check for `403 BadJwtToken`.

## Notes

- Keep the `ui-` class prefix (or rename consistently) between `variables.css`
  and the generated pages.
- `react-router` must stay v5 — `@ionic/react-router` depends on it.
- The API runs TypeScript directly via `tsx` — there is no build step; the
  Dockerfile copies `src/` and runs `npm start`.
- If the user wants a different backend (e.g. Supabase, Postgres+Prisma) or a
  different UI kit, this skill's *patterns* (optimistic-mutation-then-toast,
  token theming, custom SW flow, one-origin API) still apply — adapt rather than
  force PocketBase/Ionic.
