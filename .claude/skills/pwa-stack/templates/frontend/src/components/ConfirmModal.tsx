import { createContext, useCallback, useContext, useRef, useState, type ReactNode } from "react"
import { IonButton, IonModal } from "@ionic/react"
import { hapticTap } from "../lib/haptics"

// App-wide confirmation dialog. Any destructive action (deleting a record,
// removing a saved item, …) awaits `confirm()` before proceeding, so the whole
// app shares one styled, theme-aware sheet instead of the native alert.
export interface ConfirmOptions {
  title?: string
  message?: string
  confirmText?: string
  cancelText?: string
  danger?: boolean // tint the confirm button as destructive (default true)
}

type ConfirmFn = (opts?: ConfirmOptions) => Promise<boolean>

const ConfirmContext = createContext<ConfirmFn>(async () => false)

export const useConfirm = (): ConfirmFn => useContext(ConfirmContext)

export function ConfirmProvider({ children }: { children: ReactNode }) {
  const [opts, setOpts] = useState<ConfirmOptions | null>(null)
  const resolver = useRef<((v: boolean) => void) | null>(null)

  const confirm = useCallback<ConfirmFn>((options = {}) => {
    hapticTap()
    return new Promise<boolean>((resolve) => {
      resolver.current = resolve
      setOpts(options)
    })
  }, [])

  // Resolve once, then let onDidDismiss's own settle be a no-op.
  const settle = (value: boolean) => {
    resolver.current?.(value)
    resolver.current = null
    setOpts(null)
  }

  const danger = opts?.danger ?? true

  return (
    <ConfirmContext.Provider value={confirm}>
      {children}
      <IonModal
        isOpen={opts !== null}
        onDidDismiss={() => settle(false)}
        breakpoints={[0, 1]}
        initialBreakpoint={1}
        className="ui-confirm-modal"
      >
        <div className="ui-confirm">
          <div className="ui-confirm-title">{opts?.title ?? "Are you sure?"}</div>
          {opts?.message && <p className="ui-confirm-msg">{opts.message}</p>}
          <div className="ui-confirm-actions">
            <IonButton fill="outline" color="medium" onClick={() => settle(false)}>
              {opts?.cancelText ?? "Cancel"}
            </IonButton>
            <IonButton color={danger ? "danger" : "primary"} onClick={() => settle(true)}>
              {opts?.confirmText ?? "Confirm"}
            </IonButton>
          </div>
        </div>
      </IonModal>
    </ConfirmContext.Provider>
  )
}
