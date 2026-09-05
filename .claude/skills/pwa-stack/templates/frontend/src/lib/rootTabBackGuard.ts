/**
 * Blocks browser-level back navigation while the user is on a tab-root page.
 *
 * Ionic tab clicks push history entries (@ionic/react-router's handleChangeTab
 * calls react-router's navigate() with no options), so the OS back gesture —
 * iOS edge swipe, trackpad swipe, Android back — pops between tabs, which reads
 * as a bug. IonRouterOutlet's swipeGesture prop only disables Ionic's own JS
 * gesture; it can't touch history.back(). This guard cancels the popstate
 * before the router's listener runs.
 *
 * Two layers:
 *  (a) preventDefault() on LEFT-edge touchstart — in a standalone iOS PWA this
 *      is the only way to stop the OS back gesture and its animation from
 *      starting (ionic-framework#22299). Left edge only (back gesture; the
 *      right edge is the forward gesture, and blocking it breaks end-side
 *      swipe-to-reveal rows). Touches on interactive elements are exempt so
 *      edge-adjacent taps and row swipes keep working — layer (b) still
 *      cancels the navigation for those.
 *  (b) a popstate canceller that stopImmediatePropagation()s and jumps forward
 *      again — the backstop everywhere layer (a) doesn't apply (Safari tab,
 *      desktop trackpad, Android back, touches that started on an interactive
 *      element).
 *
 * A page counts as a root if its pathname is in TAB_ROOTS, or if its history
 * entry is marked { rootEntry: true } — a tab-like button that navigates
 * manually (e.g. a "Now Playing" tab) should pass that as navigate() state
 * (with replace: true) so its destination behaves like a tab root, while the
 * same page reached by a normal drill-down keeps normal back behavior.
 *
 * Relies on react-router storing its entry index as history.state.idx (and
 * navigate() state under history.state.usr), and on listener-registration
 * order: call installRootTabBackGuard() in main.tsx, before the router
 * mounts, so stopImmediatePropagation() reaches the router's popstate handler.
 */

// Every IonTabButton href, plus "/" — edit per app.
export const TAB_ROOTS = new Set(["/", "/home"])

export function isTabRoot(pathname: string): boolean {
  return TAB_ROOTS.has(pathname.replace(/\/+$/, "") || "/")
}

// The current entry blocks back-nav: static tab root, or marked via state.
function isRootEntry(): boolean {
  return (
    isTabRoot(window.location.pathname) ||
    (window.history.state?.usr as { rootEntry?: boolean } | undefined)?.rootEntry === true
  )
}

// How far from the screen edge (px) the iOS back swipe can start.
const EDGE_PX = 32

// Touches that begin on these must never be preventDefault()ed — that would
// swallow the tap (iOS synthesizes click from the touch) or the row gesture.
const INTERACTIVE =
  "a, button, input, textarea, select, label, [role='button'], " +
  "ion-item, ion-item-sliding, ion-tab-bar, ion-segment, ion-toggle, ion-checkbox, ion-range, ion-refresher"

export function installRootTabBackGuard() {
  window.addEventListener(
    "touchstart",
    (event) => {
      if (!isRootEntry()) return
      const touch = event.touches[0]
      if (!touch || touch.clientX > EDGE_PX) return
      if (event.target instanceof Element && event.target.closest(INTERACTIVE)) return
      event.preventDefault()
    },
    { passive: false, capture: true },
  )

  // Where the UI currently is, and that entry's history index. popstate fires
  // after location has already changed, so both must be tracked ahead of time.
  let uiRoot = isRootEntry()
  let uiIdx: number = window.history.state?.idx ?? 0
  let suppressNext = false

  const sync = () => {
    uiRoot = isRootEntry()
    uiIdx = window.history.state?.idx ?? uiIdx
  }

  // All in-app navigation (router push/replace) funnels through these.
  const origPush = window.history.pushState.bind(window.history)
  const origReplace = window.history.replaceState.bind(window.history)
  window.history.pushState = (...args: Parameters<History["pushState"]>) => {
    origPush(...args)
    sync()
  }
  window.history.replaceState = (...args: Parameters<History["replaceState"]>) => {
    origReplace(...args)
    sync()
  }

  window.addEventListener("popstate", (event) => {
    if (suppressNext) {
      // The corrective go() below landing back where we were; hide it from the
      // router too, then resume normal tracking.
      suppressNext = false
      sync()
      event.stopImmediatePropagation()
      return
    }
    const idx = window.history.state?.idx
    const delta = typeof idx === "number" ? idx - uiIdx : null
    // Entries without an idx are from outside the app (direction unknowable):
    // let them through — a plain browser tab must never be back-trapped.
    if (delta !== null && delta < 0 && uiRoot) {
      // Backward navigation away from a root: cancel by jumping forward to
      // the entry we were on, and never let the router see either popstate.
      suppressNext = true
      event.stopImmediatePropagation()
      window.history.go(-delta)
      return
    }
    sync()
  })
}
