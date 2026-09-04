import { useRef, type ReactNode } from "react"
import { IonIcon, IonItem, IonItemOption, IonItemOptions, IonItemSliding } from "@ionic/react"
import { pencil, trash } from "ionicons/icons"

/** Swipe-to-reveal owner actions behind a card-style list row: optional edit
 *  plus delete. The reveal closes itself when an option is chosen, so the row
 *  never sits half-open behind the confirm sheet (or after a cancel).
 *  `onDelete` should route through `useConfirm()` (ConfirmModal) — this
 *  component reveals the action; the confirmation sheet guards it. */
export function SlidingActions({
  onEdit,
  onDelete,
  children,
}: {
  onEdit?: () => void
  onDelete: () => void
  children: ReactNode
}) {
  const slidingRef = useRef<HTMLIonItemSlidingElement>(null)
  const act = (fn: () => void) => {
    void slidingRef.current?.close()
    fn()
  }
  return (
    <IonItemSliding ref={slidingRef} className="ui-slide">
      <IonItem lines="none" detail={false} className="ui-slide-item">
        {children}
      </IonItem>
      <IonItemOptions side="end" onIonSwipe={() => act(onDelete)}>
        {onEdit && (
          <IonItemOption className="ui-slide-edit" onClick={() => act(onEdit)}>
            <IonIcon slot="icon-only" icon={pencil} />
          </IonItemOption>
        )}
        <IonItemOption className="ui-slide-delete" expandable onClick={() => act(onDelete)}>
          <IonIcon slot="icon-only" icon={trash} />
        </IonItemOption>
      </IonItemOptions>
    </IonItemSliding>
  )
}
