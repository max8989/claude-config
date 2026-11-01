# PocketBase dashboard on the app origin

Every generated app exposes the built-in PocketBase dashboard at
`https://<app-domain>/_/`, including in production. This is independent of the
optional in-app roles/admin feature. Operators sign in with their PocketBase
superuser credentials; no VPN, private server IP, or second public port is
required. The PWA's data access still goes through its application API.

## API gateway contract

Generate the dashboard proxy in the Node API, using the configured internal
`PB_URL`. The host's existing HTTPS proxy forwards the entire app origin to
`APP_PORT`, including `/_/` and the dashboard's API requests. Keep the direct
PocketBase host port loopback-bound for optional local diagnostics.

- Redirect `/_` to `/_/`. Proxy `GET`/`HEAD` for `/_/` and its descendants to
  PocketBase with the original path, including dashboard assets and routes.
  Serve PocketBase's login page without requiring a PWA session.
- Preserve the existing user login/refresh and read-only file passthroughs.
  Also forward the pinned release's superuser authentication discovery,
  password login, refresh, and any enabled OTP/MFA flow to PocketBase. These
  exact method/path exceptions use PocketBase's native authentication; do not
  require an existing superuser session before login can succeed.
- Support the management API calls used by that release's dashboard, including
  collection/schema and record management, settings, logs, backups, and crons.
  Validate the **browser's PocketBase superuser token** before forwarding
  protected management requests. Use a separate per-request PocketBase client
  and validate against `_superusers` (for example with `authRefresh()`), not
  merely decoded JWT claims or the application's `role === "admin"`.
- Forward the browser's credentials unchanged. Never authenticate a dashboard
  request with the API service's long-lived superuser client, inject its token,
  or send `PB_ADMIN_PASSWORD` to the browser. Keep application collection rules
  locked down; dashboard access must not grant ordinary users raw record CRUD.
- Inventory the pinned dashboard's requests before defining the route list.
  Account for signed download/file tokens and realtime handshakes when used:
  their explicit routes must retain PocketBase's native token validation and
  subscription authorization rather than incorrectly requiring a bearer
  header on every request. Do not turn these exceptions into a generic bypass.
- Register explicit application routes, including `/api/health` and optional
  `/api/events`, without collisions with PocketBase management namespaces.
  Reject unknown API paths and unauthorized raw collection requests; do not
  turn the existing auth-only proxy into an unrestricted `/api/*` proxy.
- Preserve upstream status codes, authentication errors, content types,
  redirects, query strings, and streaming bodies. Support multipart record
  uploads and backup transfers without forcing them through the app's JSON
  parser or error envelope. Use only the configured upstream, never a URL
  supplied by the request.

Use HTTPS and rate-limit the public authentication endpoints. Preserve
PocketBase's login and MFA behavior. A VPN-only or private-subnet requirement
must not be the generated default for the public dashboard.

## Frontend routing

The Vite development proxy forwards both `/api` and `/_` (including `/_/`
descendants) to the Node API. The server's SPA fallback must exclude these
paths. In `src/sw.ts`, exclude `/api`, `/_`, and their descendants from app
navigation fallbacks and runtime caching, so a controlling PWA service worker
cannot replace the dashboard with the app shell or cache management responses.

## Verification and handoff

Add generated API tests for dashboard HTML/assets, superuser authentication,
authenticated management calls, and rejected anonymous, expired, ordinary-user,
and in-app-admin tokens. Verify that rejected raw record requests never run
with the service account's authority and that `/api/health`, app resource
routes, app login/refresh, and file access keep working.

Through the app origin, verify dashboard login, page reload, collection and
record browsing, a disposable record write, settings, and any enabled upload,
backup, or MFA flow. Check with the PWA service worker already controlling the
origin. An HTML 200 alone does not prove the dashboard works. For an authorized
deployment, repeat through the public HTTPS URL without a VPN. Distinguish
generated/mocked checks from a real deployed-browser check.

Document `https://<app-domain>/_/` and superuser login in the generated README.
The direct `PB_ADMIN_PORT` is an optional diagnostic endpoint, not the normal
dashboard address. Updating this skill does not retrofit existing deployments;
they need the gateway and service worker changes applied and redeployed.

Check current [PocketBase authentication](https://pocketbase.io/docs/authentication/),
[collection access rules](https://pocketbase.io/docs/api-rules-and-filters/), and
the pinned dashboard's requests when implementing this contract.
