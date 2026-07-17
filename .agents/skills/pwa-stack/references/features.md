# Optional features

Four features are toggleable at scaffold time. Generate only what's chosen;
files and blocks tied to a feature carry a `[FEATURE: <name>]` marker in the
templates so you know what to drop. Turning a feature **off** means: don't
generate that code, don't install its deps, don't add its collection/env.

---

## `web-push` — Web Push notifications

The distinctive piece: reminders/alerts even when the app is closed. Requires
HTTPS and (on iOS) the app installed to the home screen.

Include when on:
- **Deps:** `web-push` (api), nothing extra on the client.
- **Env:** `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`,
  `VITE_VAPID_PUBLIC_KEY` (generate with `npx web-push generate-vapid-keys`).
- **DB:** `push_subscriptions` collection (in the init migration).
- **API:** `push.ts` (configure VAPID + `sendToUsers`), `routes/push.ts`
  (subscribe/unsubscribe/status), a notify runner + a `node-cron` tick, and
  optionally an admin broadcast route.
- **Client:** `lib/push.ts` (subscribe/status/unsubscribe), the two `sw.ts`
  listeners (`push`, `notificationclick`), and the Notifications toggle in the
  profile/settings page.

Omit when off: delete all of the above, the manifest still works, and the SW
keeps only its precache + update logic.

---

## `realtime` — Server-Sent Events

Live updates across clients/tabs without polling.

Include when on:
- **API:** an in-process `EventEmitter` on `Deps`, every mutation emits a
  `"<resource>-changed"` event, and `routes/events.ts` streams it over
  `/api/events` (token via query string, `:hb` heartbeat).
- **Client:** the single `EventSource` in `App.tsx` that invalidates the
  resource query on each event.

Omit when off: drop the bus, the events route, and the `EventSource` effect.
Queries still refresh via `staleTime` + `refetchOnWindowFocus` + mutation
invalidation — just not cross-client-instantly.

---

## `roles` — admin role + admin screen

A two-tier user model (`admin` / `member`) with an admin-only tab.

Include when on:
- **DB:** `role` select field on `users` (in the init migration).
- **API:** `requireAdmin` preHandler; admin-only routes.
- **Client:** `user.role === "admin"` gate in `App.tsx`, the Admin tab/page,
  and any admin-only queries (member list, broadcast, audit).

Omit when off: users are all equal; drop the `role` field, `requireAdmin`, the
admin page/tab, and the `"admin" | "member"` union in `types.ts`.

---

## `ios` — iOS PWA install tuning

Make the installed iOS PWA feel native.

Include when on:
- `setupIonicReact({ swipeBackEnabled: false })` and suppress Ionic's
  back-transition on iOS (the OS edge-swipe already animates it).
- `viewport-fit=cover`, `user-scalable=no`, `maximum-scale=1`,
  `touch-action: manipulation`, `-webkit-text-size-adjust: 100%`.
- Media-scoped `<meta name="theme-color">` tags kept in sync by `lib/theme.ts`.
- Haptics on interactions.
- Install instructions in the README (Share → Add to Home Screen, iOS 16.4+ for
  push).

Omit when off: keep default Ionic gestures/zoom; haptics can stay (harmless
no-op) or go.

---

## Always included (the spine)

Regardless of toggles: the API-fronts-PocketBase model, auth-only client + `api()`
wrapper, TanStack Query with optimistic mutations + toasts + global loading bar,
the token theme system with light/dark, the custom SW + prompt-to-update flow,
the Fastify DI/route structure, the Docker Compose stack, and the one example
resource wired end to end.
