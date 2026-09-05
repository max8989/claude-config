import {
  createContext,
  useCallback,
  useContext,
  useRef,
  useState,
  type ReactNode,
} from "react"
import { IonButton, IonModal } from "@ionic/react"
import { hapticTap } from "../lib/haptics"
import "./ConfirmModal.css"

export interface ConfirmOptions {
  title?: string
  message?: string
  confirmText?: string
  cancelText?: string
  danger?: boolean
}

type Confirm = (options?: ConfirmOptions) => Promise<boolean>

const ConfirmContext = createContext<Confirm>(async () => false)

export function useConfirm(): Confirm {
  return useContext(ConfirmContext)
}

export function ConfirmProvider({ children }: { children: ReactNode }) {
  const [options, setOptions] = useState<ConfirmOptions | null>(null)
  const resolvePending = useRef<((confirmed: boolean) => void) | null>(null)

  const settle = useCallback((confirmed: boolean) => {
    resolvePending.current?.(confirmed)
    resolvePending.current = null
    setOptions(null)
  }, [])

  const confirm = useCallback<Confirm>((nextOptions = {}) => {
    return new Promise<boolean>((resolve) => {
      // Keep a second caller from replacing or stranding the open request.
      if (resolvePending.current) {
        resolve(false)
        return
      }

      hapticTap()
      resolvePending.current = resolve
      setOptions(nextOptions)
    })
  }, [])

  const danger = options?.danger ?? true

  return (
    <ConfirmContext.Provider value={confirm}>
      {children}
      <IonModal
        isOpen={options !== null}
        onDidDismiss={() => settle(false)}
        breakpoints={[0, 1]}
        initialBreakpoint={1}
        className="ui-confirm-modal"
        aria-label={options?.title ?? "Are you sure?"}
      >
        <div className="ui-confirm">
          <h2 className="ui-confirm-title">{options?.title ?? "Are you sure?"}</h2>
          {options?.message ? <p className="ui-confirm-message">{options.message}</p> : null}
          <div className="ui-confirm-actions">
            <IonButton fill="outline" color="medium" onClick={() => settle(false)}>
              {options?.cancelText ?? "Cancel"}
            </IonButton>
            <IonButton color={danger ? "danger" : "primary"} onClick={() => settle(true)}>
              {options?.confirmText ?? "Confirm"}
            </IonButton>
          </div>
        </div>
      </IonModal>
    </ConfirmContext.Provider>
  )
}
