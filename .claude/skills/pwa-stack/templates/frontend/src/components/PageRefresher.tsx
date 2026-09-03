import { IonRefresher, IonRefresherContent, type RefresherCustomEvent } from "@ionic/react"
import { useQueryClient } from "@tanstack/react-query"

/** Pull-to-refresh for a page: refetches the queries under the given key
 *  prefixes and keeps the spinner up until they all settle. */
export function PageRefresher({ queryKeys }: { queryKeys: readonly (readonly string[])[] }) {
  const queryClient = useQueryClient()

  const handleRefresh = async (event: RefresherCustomEvent) => {
    try {
      await Promise.all(queryKeys.map((queryKey) => queryClient.refetchQueries({ queryKey })))
    } finally {
      event.detail.complete()
    }
  }

  return (
    <IonRefresher slot="fixed" onIonRefresh={handleRefresh}>
      <IonRefresherContent />
    </IonRefresher>
  )
}
