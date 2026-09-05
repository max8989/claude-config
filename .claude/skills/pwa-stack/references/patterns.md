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
    if (res.status === 401) expireSession()   // token died → app unmounts to login
    let message = res.statusText
    try { message = (await res.json()).message ?? message } catch {}
    throw new ApiError(res.status, message)
  }
  return res.status === 204 ? (undefined as T) : (res.json() as Promise<T>)
}
```

**Never guard that 401 branch with `pb.authStore.isValid`.** `isValid` only
checks the JWT's local `exp`, so it is already `false` for the single most
common cause of a 401 — an expired token. Guarding on it means the one case you
need to log out for is the one case that doesn't, and the app sits there
mounted and "logged in", 401ing every request and rendering empty pages, with
no way out but a manual logout. Clear unconditionally on 401; `expireSession()`
(§6) is the shared exit so the login screen can explain itself.

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
2s + checkmark, failure = 3s + alert icon + danger color, both bottom.

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
validated by the same `requireUser` hook. Key the effect on the `user` object so
a token refresh (§6) re-opens the stream with the new token — a URL captured
once would keep reconnecting with a token that eventually expires. The server
sends a `:hb` comment heartbeat every ~25s so proxies don't reap idle
connections. Defer invalidation while a mutation is in flight so a refetch can't
clobber optimistic state.

---

## 6. Auth: roster + password, `requireUser` / `requireAdmin`

- Login is a two-step roster picker: a **public** `/api/roster` endpoint lists
  active members (name + avatar), the user picks themselves and enters a
  password. PocketBase `users.listRule = "active = true"` allows the pre-auth
  list.
- `AuthContext` wraps `pb.authStore`: `user` comes from `authStore.record`
  **gated on `authStore.isValid`**, and `authStore.onChange` re-renders on
  login/logout. A dead token anywhere calls `expireSession()`, which unmounts
  the app back to the login screen.
- API side: a `requireUser` preHandler validates the bearer token by asking
  PocketBase to refresh it; `requireAdmin` [FEATURE: roles] additionally checks
  `req.user.role === "admin"`.

### Session expiry — get this right the first time

An installed PWA lives for months and is opened in bursts, so token expiry is a
routine event, not an edge case. Three things must hold, and they are easy to
get subtly wrong in a way that only shows up weeks after launch:

**1. Never trust `authStore.record` on its own.** An expired token leaves both
the token *and* the record sitting in localStorage — nothing prunes the store,
and `isValid` only compares `exp` to the clock. Seed React state from
`isValid ? record : null`, or the app mounts fully logged-in on a dead session.

**2. Slide the session on every resume.** Tokens are stateless and expire a
fixed time after *login*, no matter how heavily the app is used, so without a
refresh the app dies mid-use on a schedule. `authRefresh()` mints a new token
(resetting the clock) and doubles as a server-side check that the old one is
still accepted. Fire it on mount and on `visibilitychange` → visible (what
fires when an installed PWA returns from the app switcher), throttled to ~1/h.

**3. Only an auth rejection ends a session.** A failed refresh from being
offline or a server restart arrives as status `0` — logging out on that strands
the user on a login screen they can't get past. Clear on `401`/`403` only.

```ts
// lib/pb.ts — session lifecycle lives next to the client, not in React:
// api.ts kills sessions from outside the tree, and the login screen needs to
// know whether the last session ended by itself or by the user's own logout.
let expired = false
export const sessionExpired = () => expired
export function expireSession() {           // ended on its own
  if (pb.authStore.token) expired = true    // only flag if there was something to lose
  pb.authStore.clear()
}
export function clearSessionExpired() { expired = false }   // login() and logout() reset it
export function dropExpiredToken() {        // call on boot + on every resume
  if (!pb.authStore.isValid && pb.authStore.record) expireSession()
}

// auth/AuthContext.tsx
const REFRESH_EVERY_MS = 60 * 60 * 1000
let lastRefresh = 0
async function refreshSession() {
  if (!pb.authStore.isValid || Date.now() - lastRefresh < REFRESH_EVERY_MS) return
  lastRefresh = Date.now()
  try { await pb.collection("users").authRefresh() }
  catch (err) {
    const status = (err as { status?: number } | null)?.status
    if (status === 401 || status === 403) expireSession()
    else lastRefresh = 0                    // offline/transient: retry on the next resume
  }
}
useEffect(() => {
  const check = () => { dropExpiredToken(); void refreshSession() }
  check()
  const onVisibility = () => { if (document.visibilityState === "visible") check() }
  document.addEventListener("visibilitychange", onVisibility)
  return () => document.removeEventListener("visibilitychange", onVisibility)
}, [])
```

Expose `expired` from the context and have the login screen say so — one line
in the app's language ("Session expired — please sign in again"). Otherwise a
timed-out session reads as a bug: the user gets dumped back to a login form for
no visible reason.

The other half of this lives in the migration — `users.authToken.duration`
(`templates/pocketbase/pb_migrations/0001_init.js`) sets the window the sliding
refresh slides *within*. PocketBase's default is 5 days; the template raises it
to 30. It's the one real trade-off here (a longer window means a token lifted
off a lost phone stays usable longer), so state the number at hand-off rather
than leaving the user to discover it.

[FEATURE: realtime] If the SSE `EventSource` carries the token in its URL
(§5), keep its `useEffect` keyed on the `user` object so a refresh re-opens the
stream with the new token instead of leaving a stale one to expire mid-stream.

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

## 11. Install: an in-app "Install app" button on the settings page

A PWA is only installable if the user finds the install affordance — the browser
hides its own behind a menu, and iOS Safari has none at all. Every generated app
therefore ships an explicit **Install app** button in its settings/profile page,
backed by `lib/install.ts` (copy it verbatim from
`templates/frontend/src/lib/install.ts`).

How it works:

- `initInstall()` runs in `main.tsx` **before React mounts** —
  `beforeinstallprompt` often fires before the settings page has ever been
  rendered, so a listener registered inside a component misses it.
- It captures and `preventDefault()`s the event (killing Chrome's mini-infobar),
  tracks `appinstalled`, and detects an already-installed session with
  `display-mode: standalone` / `navigator.standalone`.
- `useInstallState()` is a `useSyncExternalStore` over a **cached, referentially
  stable snapshot** — recomputing the object per render loops the store.
- The page calls `promptInstall()` when `canPrompt` is true (Chrome / Edge /
  Android: native dialog, toast on `accepted`); otherwise it opens a small
  bottom sheet with manual *Add to Home Screen* steps, branching on `isIOS()`
  (Share → Add to Home Screen) vs generic (browser menu → Install app).
- The whole section is hidden when `installed` is true, so the installed app
  doesn't offer to install itself.

```tsx
const [showInstall, setShowInstall] = useState(false)
const { canPrompt, installed } = useInstallState()

async function handleInstall() {
  if (canPrompt) {
    if (await promptInstall()) toast.success("App installed 🎉")
  } else {
    setShowInstall(true)   // manual "Add to Home Screen" sheet
  }
}
```

`isIOS()` must treat iPadOS as iOS: iPadOS 13+ reports a `Macintosh` UA, so
match `/Macintosh/` **plus** `navigator.maxTouchPoints > 1`.

[FEATURE: web-push] On iOS this button is load-bearing beyond convenience —
Web Push on iOS 16.4+ only works from a Home-Screen-installed PWA, so the
install steps are the entry point to notifications working at all.

---

## 12. Small touches that carry the "native app" feel

- **Haptics** (`lib/haptics.ts`): `navigator.vibrate` wrapped to be a silent
  no-op where unsupported (iOS Safari, desktop). Tap on writes, success pattern
  on completion.
- **Skeletons** while queries load, not spinners.
- **Lazy-load** every page except Login/Home; warm the likely-next chunks after
  first paint so tab switches don't flash the fallback.
- [FEATURE: ios] `viewport-fit=cover` + `touch-action: manipulation` +
  `user-scalable=no` for a chromeless feel.

---

## 13. Destructive actions: one app-wide confirmation sheet

A misclick on a trash icon must never destroy data. Every destructive action
(delete a record, remove a saved item, …) goes through **one** promise-based
confirmation sheet — never the native `window.confirm`, and never a per-page
modal copy.

Copy `templates/frontend/src/components/ConfirmModal.tsx` verbatim. It exposes:

- `ConfirmProvider` — rendered once near the root (inside `IonApp`, wrapping
  the shell). It owns a single `IonModal` bottom sheet
  (`breakpoints={[0, 1]}`, `initialBreakpoint={1}`).
- `useConfirm()` — returns `confirm(opts) => Promise<boolean>`, so call sites
  read linearly:

```tsx
const confirm = useConfirm()
async function removeWithConfirm(id: string, label?: string) {
  const ok = await confirm({
    title: "Remove from review?",
    message: label
      ? `“${label}” and its progress will be deleted.`
      : "This item and its progress will be deleted.",
    confirmText: "Remove",
  })
  if (ok) removeSaved.mutate(id)
}
```

Mechanics that matter:

- The pending resolver lives in a ref and **resolves exactly once**: the
  buttons `settle(true/false)`, and `onDidDismiss` (backdrop tap, sheet
  swipe-down) settles `false` as a no-op if a button already resolved.
  Dismissing is always a safe "no".
- `danger` defaults to `true` — the confirm button renders `color="danger"`;
  pass `danger: false` for non-destructive confirmations.
- `hapticTap()` fires when the sheet opens, matching the write pattern (§3).
- When several pages delete the same kind of thing, wrap the wording once
  (e.g. a `useConfirmRemove(label?)` hook exported next to the provider) so
  the copy stays identical everywhere.
- Also route the "unsave" side of save/bookmark **toggles** through it when
  unsaving loses server-side state (e.g. spaced-repetition progress) — a
  toggle that silently discards progress is still a destructive action.

Sheet styles are `ui-` classes in `variables.css` (theme-aware via tokens):

```css
ion-modal.ui-confirm-modal { --height: auto; --border-radius: 20px 20px 0 0; }
.ui-confirm { padding: var(--sp-5) var(--sp-4) calc(var(--sp-4) + var(--ion-safe-area-bottom, 0px)); }
.ui-confirm-title { font-size: 19px; font-weight: 700; letter-spacing: -0.01em; margin-bottom: var(--sp-2); }
.ui-confirm-msg { margin: 0; color: var(--ink-2); font-size: 14.5px; line-height: 1.4; }
.ui-confirm-actions { display: flex; gap: var(--sp-2); margin-top: var(--sp-4); }
.ui-confirm-actions ion-button { flex: 1; margin: 0; }
```

---

## 14. Pull-to-refresh on every tab-root page

Users expect a mobile list to refresh on pull-down. One tiny component covers
the whole app because server state is all TanStack Query (§2): copy
`templates/frontend/src/components/PageRefresher.tsx` verbatim — an
`IonRefresher` that `refetchQueries` every key prefix it's given and keeps the
spinner up until they all settle.

Render it as the **first child of `IonContent`** on every tab-root/list page,
passing the key families that page displays:

```tsx
<IonContent fullscreen>
  <PageRefresher queryKeys={[keys.podcasts, keys.stats, keys.lookups]} />
  <div className="ui-content">…</div>
</IonContent>
```

Use `refetchQueries` (not `invalidateQueries`): the returned promise resolves
when the fetches finish, which is what holds the spinner honestly; invalidate
alone would complete the refresher before new data arrives. Detail pages
pushed on top of a tab don't need one unless they show list-like server state.

---

## 15. Back navigation: the OS edge-swipe owns it, not Ionic

Ionic's JS swipe-back gesture (on by default in iOS mode) **competes** with the
OS edge-swipe that Safari / installed PWAs already translate into a real
`history.back()`: one physical swipe triggers both, popping two history entries
(landing on the tab root instead of the previous page) or freezing the screen
mid-transition. Ionic's `goBack()` also falls back to `"/"` when its route
bookkeeping is missing (deep link, reload). The native gesture alone always
targets the true previous page, so disable Ionic's copy at setup:

```tsx
setupIonicReact({ swipeBackEnabled: false })
```

Second half of the pattern: on iOS the OS edge-swipe already animates the back
navigation (the system slides in a snapshot of the previous page), then Ionic
replays its own back transition on top — a visible double animation. Suppress
Ionic's transition for back navigations on iOS; forward pushes keep the normal
animation. Lives in the component rendering the outlet (inside
`IonReactRouter`, since `useIonRouter` needs the router context):

```tsx
const { routeInfo } = useIonRouter()
const animated = !(isPlatform("ios") && routeInfo?.routeDirection === "back")
// ...
<IonRouterOutlet animated={animated}>
```

Both halves are pure configuration and work identically on the react-router
v5 and v6 integrations.

Third half: **block back navigation on tab roots**. Ionic tab clicks push real
history entries (`handleChangeTab` → react-router `navigate()` with no
options), so with the OS gesture owning back, an edge-swipe on a root tab pops
to whatever tab was visited before — reads as a bug. Copy
`templates/frontend/src/lib/rootTabBackGuard.ts` verbatim, set `TAB_ROOTS` to
every `IonTabButton` href plus `"/"` (the one prohibited list — `isTabRoot` is
exported so nothing else ever keeps a second copy), and call
`installRootTabBackGuard()` in `main.tsx` **before** `createRoot` — its
popstate canceller must register ahead of react-router's listener for
`stopImmediatePropagation()` to win.

A first-generation guard was removed from this skill for causing regressions:
it `preventDefault()`ed `touchstart` at **both** screen edges with no target
exemption, which killed taps on edge-adjacent controls (`preventDefault` on
`touchstart` suppresses the synthesized click) and broke end-side
swipe-to-reveal rows (§16), which start near the right edge. The current
template avoids both failure modes by design — keep these properties if you
ever touch it:

- Layer (a): `preventDefault()` on **left-edge** `touchstart` only (the iOS
  back-gesture edge; the right edge is forward), and only when the touch does
  not start on an interactive element. This is the only way to stop the OS
  gesture and its animation in a standalone PWA (ionic-framework#22299).
- Layer (b): a popstate canceller as the universal backstop (Safari tab,
  desktop trackpad, Android back, and the touches layer (a) exempted). It
  computes direction from react-router's `history.state.idx` delta and, on a
  back-nav leaving a root, `stopImmediatePropagation()`s and jumps forward
  again. Entries without an `idx` (outside the app) pass through — a plain
  browser tab is never back-trapped.

Pushed detail pages keep normal back behavior automatically — the guard only
blocks when the entry being *left* is a root. Dynamic roots: a tab-like button
that navigates manually instead of via `IonTabButton` `href` (e.g. a
"Now Playing" tab that jumps to the current episode) must navigate with
`navigate(path, { replace: true, state: { rootEntry: true } })` — `replace` so
the page it was tapped from never sits behind it in history, and the
`rootEntry` marker makes the guard treat that entry as a root, while the same
page reached by a normal drill-down keeps its back behavior.

Verify on a real device: DevTools touch emulation simulates touch *events* for
the page's own JS, but the OS edge-swipe is recognized at the
OS/browser-chrome level, below what emulation reaches — desktop testing proves
nothing about layer (a).

---

## 16. Editable list rows: swipe-to-reveal owner actions

Any resource the user creates and may later **edit or delete** (their own
items, series, entries, …) gets its row actions behind an iOS-style swipe, not
inline buttons — the list stays clean, and destructive controls aren't one
stray tap away. One component covers it everywhere; copy
`templates/frontend/src/components/SlidingActions.tsx` verbatim.

Usage — wrap the existing row markup; only rows the user owns get wrapped:

```tsx
{items.map((item) =>
  item.mine ? (
    <SlidingActions
      key={item.id}
      onEdit={() => setEditing(item)}            // optional — omit for delete-only
      onDelete={() => void confirmDelete(item)}  // routes through useConfirm (§13)
    >
      {itemRow(item)}
    </SlidingActions>
  ) : (
    itemRow(item)
  ),
)}
```

Mechanics that matter:

- **Always pair with the §13 confirmation sheet**: `onDelete` awaits
  `confirm({...})` and only then fires the mutation. The swipe reveals the
  action; the sheet guards it. A full swipe-through (`onIonSwipe` on the
  expandable option) triggers the same confirmed path as a tap.
- **The reveal closes itself** before running the action (the `act` helper
  calls `slidingRef.current?.close()` first). Without this the row stays stuck
  half-open after the user cancels the confirm sheet — close on action, not on
  outcome.
- Edit opens an edit sheet/modal (same `ui-confirm-modal` bottom-sheet styling
  as §13, with form fields and Cancel/Save); delete goes straight to the
  confirm sheet.
- Rows rendered as custom cards (a `Link`/`div` with `ui-row` classes) ride
  inside a **transparent** `IonItem` so the revealed options match the card's
  rounded silhouette — that's what the `ui-slide-item` variables do.

Styles are `ui-` classes in `variables.css` (theme-aware via tokens):

```css
/* Swipeable card rows (owner edit/delete). The card .ui-row rides inside a
   transparent ion-item so the revealed options share its rounded silhouette. */
ion-item-sliding.ui-slide { border-radius: 14px; overflow: hidden; }
.ui-slide ion-item.ui-slide-item {
  --background: transparent;
  --padding-start: 0; --padding-end: 0;
  --inner-padding-start: 0; --inner-padding-end: 0;
  --min-height: 0;
  --border-width: 0; --inner-border-width: 0;
}
.ui-slide .ui-row { width: 100%; }
ion-item-option.ui-slide-delete { background: var(--danger); color: #fff; font-size: 22px; }
ion-item-option.ui-slide-edit { background: var(--ink-3); color: #fff; font-size: 22px; }
```

Match the row's `border-radius` to the app's own card radius. If rows sit in a
flex column with `gap`, the sliding wrapper needs no margin of its own.
