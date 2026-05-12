import { Controller } from "@hotwired/stimulus"
import { fetchInternal } from "../utilities/fetchInternal"

export default class extends Controller {
  static targets = [
    "form",
    "flowCard",
    "windowCard",
    "statusCard",
    "monthPill",
    "flowInput",
    "windowInput",
    "monthsInput",
    "statusInput",
    "agencySelect",
    "launchAlt",
    "linkCard",
    "linkLabel",
    "linkInput",
    "linkOpen",
    "linkCopied",
  ]

  static values = {
    flow: String,
    window: String,
    months: Number,
    status: String,
  }

  connect() {
    this.applyFlowVisibility()
    this.applyWindowVisibility()
    this.applyCardSelection(this.flowCardTargets, this.flowValue)
    this.applyCardSelection(this.windowCardTargets, this.windowValue)
    this.applyCardSelection(this.statusCardTargets, this.statusValue)
    this.applyMonthPills()
    this.syncHiddenInputs()
  }

  selectFlow(event) {
    this.flowValue = event.currentTarget.dataset.value
    this.applyCardSelection(this.flowCardTargets, this.flowValue)
    this.applyFlowVisibility()
    this.syncHiddenInputs()
    this.invalidateLink()
  }

  selectWindow(event) {
    this.windowValue = event.currentTarget.dataset.value
    this.applyCardSelection(this.windowCardTargets, this.windowValue)
    this.applyWindowVisibility()
    this.syncHiddenInputs()
    this.invalidateLink()
  }

  selectMonths(event) {
    this.monthsValue = parseInt(event.currentTarget.dataset.value, 10)
    this.applyMonthPills()
    this.syncHiddenInputs()
    this.invalidateLink()
  }

  selectStatus(event) {
    this.statusValue = event.currentTarget.dataset.value
    this.applyCardSelection(this.statusCardTargets, this.statusValue)
    this.syncHiddenInputs()
    this.invalidateLink()
  }

  selectAgency() {
    this.invalidateLink()
  }

  toggleHint(event) {
    const step = event.currentTarget.closest(".launcher__step")
    const hint = step?.querySelector(".launcher__step-hint")
    if (hint) hint.hidden = !hint.hidden
  }

  async launch(event) {
    event.preventDefault()
    const button = event.currentTarget
    const launchType = button.dataset.launchType || "tokenized"

    button.disabled = true
    try {
      const formData = new FormData(this.formTarget)
      formData.set("launch_type", launchType)
      const { url } = await fetchInternal(this.formTarget.action, {
        method: this.formTarget.method.toUpperCase(),
        headers: { Accept: "application/json" },
        body: JSON.stringify(Object.fromEntries(formData.entries())),
        credentials: "same-origin",
      })
      this.linkInputTarget.value = url
      this.linkOpenTarget.href = url
      this.linkLabelTarget.textContent =
        launchType === "generic" ? "Generic link" : "Tokenized link"
      this.linkCardTarget.hidden = false
      this.linkCopiedTarget.hidden = true
    } finally {
      button.disabled = false
    }
  }

  async copy() {
    const url = this.linkInputTarget.value
    if (!url) return
    try {
      await navigator.clipboard.writeText(url)
    } catch (_e) {
      this.linkInputTarget.focus()
      this.linkInputTarget.select()
      document.execCommand("copy")
    }
    this.linkCopiedTarget.hidden = false
  }

  // private

  applyFlowVisibility() {
    this.element.dataset.launcherFlowValue = this.flowValue
    const isCe = this.flowValue === "activity"
    this.launchAltTarget.disabled = isCe
  }

  applyWindowVisibility() {
    this.element.dataset.launcherWindowValue = this.windowValue
  }

  applyCardSelection(cards, selectedValue) {
    cards.forEach((card) => {
      const isSelected = card.dataset.value === selectedValue
      card.classList.toggle("launcher__rcard--selected", isSelected)
      card.setAttribute("aria-checked", String(isSelected))
    })
  }

  applyMonthPills() {
    this.monthPillTargets.forEach((pill) => {
      const isActive = parseInt(pill.dataset.value, 10) === this.monthsValue
      pill.classList.toggle("launcher__month-pill--active", isActive)
    })
  }

  syncHiddenInputs() {
    this.flowInputTarget.value = this.flowValue
    this.windowInputTarget.value = this.windowValue
    this.monthsInputTarget.value = this.windowValue === "renewal" ? "6" : String(this.monthsValue)
    if (this.hasStatusInputTarget) {
      this.statusInputTarget.value = this.flowValue === "activity" ? this.statusValue : ""
    }
  }

  invalidateLink() {
    if (!this.hasLinkCardTarget) return
    this.linkCardTarget.hidden = true
    this.linkInputTarget.value = ""
    this.linkOpenTarget.href = "#"
    this.linkCopiedTarget.hidden = true
  }
}
