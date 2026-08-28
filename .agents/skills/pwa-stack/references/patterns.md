# Patterns & conventions

These are the house rules that make the app feel consistent. Snippets show the
**shape**, not a version-pinned copy — write current-API code that follows the
convention. When a new project deviates, deviate on purpose.

---

## 1. Data access: auth-only PocketBase client + typed `api()` wrapper

The client PocketBase instance is auth-only. All data goes through one `fetch`
wrapper that attaches the bearer token, normalizes errors, and logs out on 401.

```ts
// lib/pb.ts
export const pb = new PocketBase("/")           // auth only: authWithPassword, authStore

// lib/api.ts
export async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers)
  if (init.body && !headers.has("content-type")) headers.set("content-type", "application/json")
  if (pb.authStore.token) headers.set("authorization", `Bearer ${pb.authStore.token}`)
  const res = await fetch(path, { ...init, headers })
  if (!res.ok) {
    if (res.status === 401 && pb.authStore.isValid) pb.authStore.clear()   // token died → app unmounts to login
    let message = res.statusText
    try { message = (await res.json()).message ?? message } catch {}
    throw new ApiError(res.status, message)
  }
  return res.status === 204 ? (undefined as T) : (res.json() as Promise<T>)
}
```

Rule: **components never call `fetch` or `pb.collection(...).getFullList` for
data.** They call query/mutation hooks that call `api()`.

---

## 2. Server state: TanStack Query with query-key families

One `QueryClient` (`staleTime` ~30s). Group every key for a resource under a
shared prefix so a single `invalidateQueries({ queryKey: keys.items })` — from a
mutation or the SSE stream — refreshes them all.

```ts
export const keys = { items: ["items"] as const, users: ["users"] as const }

export function useItems() {
  return useQuery({ queryKey: keys.items, queryFn: () => api<ItemRecord[]>("/api/items") })
}
```

---

## 3. Writes: optimistic mutation → **toast on success, rollback + toast on error**

This is the signature interaction. Every write:
1. fires a haptic in `onMutate` (feedback lands with the UI change, not after
   the round-trip),
2. optimistically patches the cache so the UI reacts instantly,
3. on error, restores the pre-mutation snapshot **and shows a failure toast** —
   without it a rolled-back write looks like the tap did nothing,
4. on success, shows a short confirmation toast (for create/delete; silent for
   cheap toggles is fine),
5. on settled, invalidates so the server is the final source of truth.

```ts
const snapshot = async () => {
  await qc.cancelQueries({ queryKey: keys.items })
  return qc.getQueryData<ItemRecord[]>(keys.items)
}
const create = useMutation({
  mutationFn: (data) => api<ItemRecord>("/api/items", { method: "POST", body: JSON.stringify(data) }),
  onMutate: async (data) => {
    hapticTap()
    const prev = await snapshot()
    qc.setQueryData(keys.items, (old) => [optimisticFrom(data), ...(old ?? [])])
    return prev                                   // context for rollback
  },
  onSuccess: () => toast.success("Created"),
  onError: (_e, _v, prev) => { if (prev) qc.setQueryData(keys.items, prev); toast.failure("Could not create") },
  onSettled: () => qc.invalidateQueries({ queryKey: keys.items }),
})
```

The toast helper is one style for the whole app (`lib/toast.ts`): success =
2s + checkmark, failure = 3s + alert icon + danger color. Both are **anchored to
the top** and **swipe-dismissible** — every toast goes through one
`present()` that always sets `position: "top"` and `swipeGesture: "vertical"`,
so no call site can opt out and drift:

```ts
import { toastController } from "@ionic/core/components/toast"

const present = (message: string, opts: Partial<ToastOptions>) =>
  toastController
    .create({
      message,
      position: "top",
      positionAnchor: "app-header",   // sits under the header, not over it
      swipeGesture: "vertical",       // swipe up to dismiss (direction follows position)
      ...opts,
    })
    .then((t) => t.present())

export const toast = {
  success: (m: string) => present(m, { duration: 2000, icon: checkmarkCircle, color: "success" }),
  failure: (m: string) => present(m, { duration: 3000, icon: alertCircle, color: "danger" }),
}
```

Top placement keeps toasts clear of the thumb zone and of the iOS home
indicator; `swipeGesture` is position-aware, so the swipe direction flips
automatically if the position ever changes. Give the app's `IonHeader` the
`id="app-header"` that `positionAnchor` refers to — without an anchor a top
toast overlaps the header on notched devices. On screens with no header, drop
`positionAnchor`; the toast then respects the safe-area inset on its own.

---

## 4. Global loading bar via `useIsMutating`

Because every write is a TanStack mutation, one component covers all of them: a
thin indeterminate bar at the top whenever `useIsMutating() > 0`. No per-button
spinners.

```tsx
export function GlobalLoadingBar() {
  return useIsMutating() ? <div className="ui-loading-bar" role="progressbar" /> : null
}
```

---

## 5. Realtime: one SSE stream that invalidates queries  [FEATURE: realtime]

Instead of PocketBase realtime, the API exposes `/api/events` (Server-Sent
Events). Every mutation in the API emits on an in-process `EventEmitter`; the
SSE route forwards it. The client opens **one** EventSource for the whole app in
`App.tsx` and, on each event, invalidates the resource key — because Ionic keeps
every tab mounted, that refetches all visible tabs at once.

```ts
const es = new EventSource(`/api/events?token=${encodeURIComponent(pb.authStore.token)}`)
es.addEventListener("items-changed", () => queryClient.invalidateQueries({ queryKey: keys.items }))
es.onopen = () => { if (connectedOnce) invalidate(); connectedOnce = true }   // catch events missed while offline
```

EventSource can't set headers, so the token rides the query string and is
validated by the same `requireUser` hook. The server sends a `:hb` comment
heartbeat every ~25s so proxies don't reap idle connections. Defer invalidation
while a mutation is in flight so a refetch can't clobber optimistic state.

---

## 6. Auth: roster + password, `requireUser` / `requireAdmin`

- Login is a two-step roster picker: a **public** `/api/roster` endpoint lists
  active members (name + avatar), the user picks themselves and enters a
  password. PocketBase `users.listRule = "active = true"` allows the pre-auth
  list.
- `AuthContext` wraps `pb.authStore`: `user` comes from `authStore.record`, and
  `authStore.onChange` re-renders on login/logout. A dead token anywhere calls
  `authStore.clear()`, which unmounts the app back to the login screen.
- API side: a `requireUser` preHandler validates the bearer token by asking
  PocketBase to refresh it; `requireAdmin` [FEATURE: roles] additionally checks
  `req.user.role === "admin"`.

---

## 7. API shape: dependency injection + one register-fn per resource

`server.ts` builds a Fastify instance with a uniform JSON error handler, a
`/api/health` check that also pings PocketBase, then calls
`register<Resource>(app, deps, requireUser)` for each route module. `Deps`
(the superuser client factory, token validator, event bus, notify runner,
paths) is injected so tests can pass an in-memory fake PocketBase.

```ts
app.setErrorHandler((err, _req, reply) => {
  const status = typeof err.status === "number" ? err.status : err.statusCode ?? 500
  reply.code(status).send({ status, message: err.message || "Internal error" })
})
// SPA fallback: unknown non-/api GETs return index.html; unknown /api paths 404.
```

Pure business logic lives in `domain/` with no Fastify types, so it unit-tests
directly.

---

## 8. Theme: CSS custom-property tokens, light `:root` + `.ion-palette-dark`

All color/spacing/motion are CSS variables in `theme/variables.css`. Light
values sit on `:root`; dark overrides on `.ion-palette-dark` (toggled by
`lib/theme.ts`, layered over Ionic's `dark.class.css`). Ionic's own `--ion-*`
variables are mapped to the brand tokens so components re-skin for free. See
`theme-tokens.md` for the full token set and how to derive a palette.

`lib/theme.ts` persists a `system|light|dark` preference and keeps the
`<meta name="theme-color">` tags in sync so the iOS status bar matches.

---

## 9. PWA: custom SW + prompt-to-update reload flow

`vite-plugin-pwa` in `injectManifest` mode; the SW is `src/sw.ts`
(Workbox `precacheAndRoute` + `clientsClaim`). Updates are **prompted**, never
silent: a new SW stays `waiting` until the user taps a reload toast
(`ReloadPrompt`), which posts `SKIP_WAITING` and reloads on `controllerchange`.
It uses the same top placement as §3 but **no `swipeGesture` and no `duration`**
— it must persist until the user chooses Reload or Later, and an accidental
swipe would silently drop the update prompt.
Never `skipWaiting()` unconditionally — it swaps precached assets under a
running page and a later lazy chunk fetch 404s.

Installed PWAs only re-check the SW on cold start, so `ReloadPrompt` also polls
every ~30 min and on `visibilitychange` → visible.

---

## 10. Notifications: web-push + cron + subscriptions  [FEATURE: web-push]

- Client subscribes via `PushManager` and POSTs the subscription
  (`endpoint` + `p256dh` + `auth`) to `/api/push/subscription`; the API dedupes
  on `(user, endpoint)`.
- `sw.ts` handles `push` (show notification) and `notificationclick` (focus or
  open the target URL).
- The API configures VAPID once, and a `node-cron` tick (or an admin action)
  calls a single-flight notify runner that sends to the relevant users and
  prunes dead subscriptions (404/410 from the push service).

---

## 11. Small touches that carry the "native app" feel

- **Haptics** (`lib/haptics.ts`): `navigator.vibrate` wrapped to be a silent
  no-op where unsupported (iOS Safari, desktop). Tap on writes, success pattern
  on completion.
- **Skeletons** while queries load, not spinners.
- **Lazy-load** every page except Login/Home; warm the likely-next chunks after
  first paint so tab switches don't flash the fallback.
- [FEATURE: ios] Disable Ionic's JS swipe-back and suppress its back-transition
  on iOS so it doesn't double up with the OS edge-swipe. `viewport-fit=cover` +
  `touch-action: manipulation` + `user-scalable=no` for a chromeless feel.
