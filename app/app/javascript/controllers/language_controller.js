import { Controller } from "@hotwired/stimulus"
import { trackUserAction } from "../utilities/api"

// Handles tracking language switching events
export default class extends Controller {
  switchLocale(event) {
    const locale = event.currentTarget.dataset.locale
    const previousLocale = document.documentElement.lang

    trackUserAction("UserManuallySwitchedLanguage", {
      locale: locale,
      previous_locale: previousLocale,
      current_locale: previousLocale,
    })
  }
}
