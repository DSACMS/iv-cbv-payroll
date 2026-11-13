import { Controller } from "@hotwired/stimulus"
import { trackUserAction } from "@js/utilities/api.js"

export default class extends Controller {
  trackClick(event) {
    const actionElement = event.target.closest("[data-hub-action]")
    if (!actionElement) return

    if (actionElement.dataset.hubAction === "review") {
      trackUserAction("HubReviewAndSubmitClicked")
      return
    }

    const section = actionElement.closest("[data-activity-type]")
    if (!section) return

    trackUserAction("HubSpokeSelected", {
      activity_type: section.dataset.activityType,
      action: actionElement.dataset.hubAction,
    })
  }
}