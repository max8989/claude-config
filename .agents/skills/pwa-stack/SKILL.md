---
name: pwa-stack
description: >-
  Scaffold a new installable, self-hosted PWA: React + Vite + Ionic React,
  TanStack Query, a custom service worker and optional Web Push, backed by a
  Fastify TypeScript API that fronts PocketBase, all in Docker Compose. Use
  whenever the user wants to START a mobile-first web app/PWA with backend,
  database, or auth, even if they do not name the stack. Triggers include "new
  PWA", "scaffold an app", "create a mobile web app", "PocketBase/Ionic app",
  and "frontend + backend + db". Includes CSS-token light/dark theming and an
  iPhone-first UI blueprint with stable thumb navigation, visible creation,
  confirmations, accessible safe areas, UI/content-language separation, and
  mobile visual QA. Ask about product hierarchy, brand, fonts, languages, and
  optional features before generating. Not for a feature added to an existing
  app of another stack or for a pure static site.
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
- `references/mobile-design.md` — required iPhone-first information
  architecture, creation, navigation, materials, localization, accessibility,
  and visual verification rules.
- `references/features.md` — what each optional feature adds/removes.
- `templates/` — the **stable** boilerplate worth copying verbatim (compose,
  Dockerfiles, vite PWA config, index.html, tsconfigs, init migration, and the
  app-wide confirmation provider). These carry `__PLACEHOLDER__` tokens and
  `[FEATURE: x]` markers.
- `scripts/make-icons.sh` — generates placeholder PWA icons from an accent
  colour + letters.

**Read `references/architecture.md`, `references/patterns.md`,
`references/theme-tokens.md`, and `references/mobile-design.md` completely
before generating any code** — they define the architecture and experience the
generated app must follow.

## Workflow

### 1. Gather requirements

First settle the app identity conversationally (ask only what wasn't given):
- **App name** and a lowercase **slug** (used for package names, dirs,
  `admin@<slug>.local`).
- One-line **description** (PWA manifest).
- The primary **resource/object**, the most important repeatable **action**, and
  what a returning user should be able to **resume** immediately.
- **Accent / brand color** (hex). Ask for a second brand color only if they
  want one.
- **Target directory** (default: a new folder named after the slug).
- **UI language** for `<html lang>` (default `en`). If users create or consume
  content in another language, record that separately as the content language.

Then ask the remaining choice-based questions in compact groups; do not repeat
answers the user already supplied:

1. **Surface tone** — `Warm` / `Cool` / `Neutral` (drives the greys behind the
   accent).
2. **Dark mode** — `Both light + dark (recommended)` / `Light only` /
   `Dark only`.
3. **Fonts** — `System fonts (recommended for native/offline)` /
   `Bundled/self-hosted` / `External web fonts` / `Custom`.
4. **Features** (multi-select) — `Web Push notifications` / `Realtime (SSE)` /
   `Roles + admin screen` / `iOS install tuning (recommended for mobile-first
   PWAs)`. See `references/features.md`.

Infer three to five root destinations from the product. Ask about navigation
only when more than one sensible hierarchy remains. Do not ask whether to make
creation discoverable, confirm sign out, support safe areas, or preserve zoom;
those are baseline quality requirements.

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
| `__FONT_HEAD__` | optional self-hosted preload or external font tags; delete for system fonts |

Also write `package.json` for `frontend/` and `api/` (not templated — generate
with the confirmed versions and the scripts from `stack.md`: frontend
`dev/build/preview/typecheck/test/test:e2e`, api `dev` = `tsx watch
src/index.ts`, `start` = `tsx src/index.ts`, `typecheck`, `test`), plus
`.gitignore` files (ignore `node_modules`, `dist`, `pb_data`, `.env`). Configure
Vitest + Testing Library for component tests and Playwright + axe for the mobile
browser matrix; keep browser binaries and reports out of git.

### 4. Generate the theme

Following `references/theme-tokens.md`, derive the full token set from the
accent + surface tone + dark-mode choice and write
`frontend/src/theme/variables.css` (light `:root`, `.ion-palette-dark` unless
light-only, the `--ion-*` bridge, and the `ui-` component classes the pages
use). Keep `__BG_LIGHT__`/`__BG_DARK__` consistent across `variables.css`,
`index.html`, `lib/theme.ts`, and the manifest in `vite.config.ts`. Wire the
chosen fonts into `--ion-font-family`, the heading font, and `index.html`.
Prefer system or bundled fonts; if external fonts were explicitly chosen,
include robust fallbacks and verify an offline launch.

### 5. Design the interaction map

Before writing components, create the compact internal UI map required by
`references/mobile-design.md`: page hierarchy, three-to-five stable root
destinations, primary action, returning/resume state, transient activity
surface, creation flow, and loading/empty/error/offline states.

Use the document's default shell when creation is central: Home, the main
collection, a centered text-labeled Create destination, the main
activity/review destination, and Profile. Keep the destinations stable;
represent a player, upload, timer, or other transient state with a mini-panel
above the tab bar rather than adding a tab. Adapt names and omit irrelevant
destinations instead of forcing this exact vocabulary onto every domain.

### 6. Generate the application code following the patterns

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

Make the interaction blueprint concrete in the generated example:

- Give Create a visible text label in the shell, on Home/collection, and in the
  empty state; use an add or compose icon, never sparkles/stars/wands for
  generic creation.
- Render newest user-created items first and provide explicit loading, error +
  retry, empty, and populated states.
- Copy `templates/frontend/src/components/ConfirmModal.tsx` and its adjacent
  CSS verbatim, mount `ConfirmProvider` once inside `IonApp`, and await it
  before delete, remove, draft abandonment, or sign out. Cancellation must
  leave state unchanged.
- Keep the tab bar, mini-panel, sheets, and form actions clear of safe areas and
  the software keyboard; keep every target at least 44×44 CSS px.
- For multilingual content, return original and localized labels through every
  relevant API DTO and select the UI-language label with one pure display
  helper. Keep authored/source content unchanged.
- Add focused component tests for discoverable creation, confirmation
  cancel/confirm behavior, stable tabs, create-flow state, error retry, and
  localized-label fallback.

### 7. Icons

Run `scripts/make-icons.sh <app>/frontend/public "<accent>" "<contrast>"
"<1-2 letters>"` to write `icon.svg`, `icon-180.png`, `icon-192.png`, and
`icon-512.png`. If no SVG→PNG converter is installed it writes the SVG and
warns — tell the user to supply the PNGs (or real artwork) before shipping.
Treat these as neutral placeholders; do not default the app mark or Create
controls to sparkle/star imagery.

### 8. Verify and hand off

- Run typecheck, unit/component tests, and production builds in `frontend/` and
  `api/` if dependencies are installed; otherwise note that `npm install` is
  needed first.
- Run the browser matrix from `references/mobile-design.md` in WebKit at
  320×568, 390×844, and 430×932. Check light/dark, reduced motion, horizontal
  overflow, 44×44 targets, safe-area/non-overlap, the keyboard-open create
  flow, dialog focus, and accessible names. Use deterministic visual fallbacks
  for screenshots. Override the app's safe-area proxy tokens with nonzero test
  insets because desktop WebKit does not emulate an iPhone notch.
- State explicitly that Playwright/WebKit is only an approximation. Include a
  physical installed-iPhone acceptance pass for standalone safe areas, status
  bar, keyboard, edge swipe, VoiceOver, offline launch, and the update flow.
- Print next steps: `cp .env.example .env` and fill it (generate VAPID keys with
  `npx web-push generate-vapid-keys` if push is on); `docker compose up -d
  --build`; create the PocketBase superuser
  (`docker compose exec pocketbase /pb/pocketbase superuser upsert <email>
  <password>`); open the PocketBase admin, add users with `active = true`; open
  the app on the API port. Remind them HTTPS (via their own reverse proxy) is
  required for service workers and Web Push in production, and that this stack
  intentionally does not include TLS/proxy.

## Notes

- Keep the `ui-` class prefix (or rename consistently) between `variables.css`
  and the generated pages.
- Match `react-router` to the installed Ionic major and verify the integration
  against current Ionic documentation; do not carry a hard-coded router major
  forward from an older scaffold.
- The API runs TypeScript directly via `tsx` — there is no build step; the
  Dockerfile copies `src/` and runs `npm start`.
- If the user wants a different backend (e.g. Supabase, Postgres+Prisma) or a
  different UI kit, this skill's *patterns* (optimistic-mutation-then-toast,
  token theming, custom SW flow, one-origin API) still apply — adapt rather than
  force PocketBase/Ionic.
