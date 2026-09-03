import { useSyncExternalStore } from "react"

// Chrome/Edge/Android fire `beforeinstallprompt` once the PWA meets the install
// criteria. It isn't part of the DOM lib, so declare the shape we use here.
interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: "accepted" | "dismissed"; platform: string }>
}

let deferredPrompt: BeforeInstallPromptEvent | null = null
let installed = false

// A cached, referentially-stable snapshot so useSyncExternalStore doesn't loop.
export interface InstallState {
  canPrompt: boolean
  installed: boolean
}

let snapshot: InstallState = { canPrompt: false, installed: false }
const subscribers = new Set<() => void>()

function update() {
  snapshot = { canPrompt: deferredPrompt !== null, installed }
  for (const cb of subscribers) cb()
}

/** Already running as an installed app (home-screen / standalone window). */
export function isStandalone(): boolean {
  return (
    window.matchMedia("(display-mode: standalone)").matches ||
    (navigator as { standalone?: boolean }).standalone === true
  )
}

// iOS/iPadOS Safari never fires `beforeinstallprompt`, so it gets manual steps
// instead. iPadOS 13+ reports as "Macintosh", hence the touch-point check.
export function isIOS(): boolean {
  const ua = navigator.userAgent
  return /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1)
}

/**
 * Register listeners at boot (from main.tsx) so we capture the event even when
 * it fires before the settings page — where we use it — has mounted.
 */
export function initInstall() {
  installed = isStandalone()
  snapshot = { canPrompt: false, installed }
  window.addEventListener("beforeinstallprompt", (e) => {
    // Suppress Chrome's mini-infobar; the settings button drives install now.
    e.preventDefault()
    deferredPrompt = e as BeforeInstallPromptEvent
    update()
  })
  window.addEventListener("appinstalled", () => {
    deferredPrompt = null
    installed = true
    update()
  })
}

/** Show the native install dialog. Returns true when the user accepts. */
export async function promptInstall(): Promise<boolean> {
  if (!deferredPrompt) return false
  await deferredPrompt.prompt()
  const { outcome } = await deferredPrompt.userChoice
  // The event is single-use; drop it (the browser re-fires it if dismissed).
  deferredPrompt = null
  update()
  return outcome === "accepted"
}

/**
 * Subscribe a component to install-availability changes (native prompt
 * arriving, or the app becoming installed).
 */
export function useInstallState(): InstallState {
  return useSyncExternalStore(
    (cb) => {
      subscribers.add(cb)
      return () => {
        subscribers.delete(cb)
      }
    },
    () => snapshot,
    () => snapshot,
  )
}
