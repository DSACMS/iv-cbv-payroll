import { Controller } from "@hotwired/stimulus"

const ERROR_MESSAGE_SELECTOR = ".usa-error-message"
const CONTROLLER_SELECTOR = '[data-controller~="error-summary"][data-error-summary-form-id-value]'

// An element with zero client rects, or any ancestor hidden
// via the `hidden` attribute, `display: none`, or `visibility: hidden`,
// is treated as not visible.
function isVisible(element) {
  if (element.getClientRects().length === 0) return false

  for (let node = element; node; node = node.parentElement) {
    if (node.hidden) return false

    const style = getComputedStyle(node)
    if (style.display === "none" || style.visibility === "hidden") return false
  }

  return true
}

export default class extends Controller {
  static targets = ["body"]
  static values = { formId: String }

  connect() {
    this.frameId = requestAnimationFrame(() => {
      if (this.element instanceof HTMLFormElement) {
        this.focusFirstErrorWithoutSummary()
        return
      }

      this.focusSummary()
    })
  }

  disconnect() {
    cancelAnimationFrame(this.frameId)
  }

  focusSummary() {
    const form = document.getElementById(this.formIdValue)

    if (!(form instanceof HTMLFormElement)) {
      console.error(`Error summary: form "${this.formIdValue}" was not found or is not a valid HTMLFormElement.`)
      return
    }

    const descriptionIds = [this.bodyTarget.id]

    form.querySelectorAll(ERROR_MESSAGE_SELECTOR).forEach((error) => {
      if (!error.id) {
        console.error("Error summary: inline error is missing an ID", error)
        return
      }

      const labelId = error.dataset.errorLabelId

      if (labelId) {
        const label = document.getElementById(labelId)

        if (label && form.contains(label)) {
          descriptionIds.push(labelId)
        } else {
          console.error(`Error summary: label "${labelId}" was not found in the form`)
        }
      }

      descriptionIds.push(error.id)
    })

    this.element.setAttribute(
      "aria-describedby",
      [...new Set(descriptionIds)].join(" ")
    )
    this.element.focus()
  }

  focusFirstErrorWithoutSummary() {
    const form = this.element
    const summaries = document.querySelectorAll(CONTROLLER_SELECTOR)

    const hasSummary = Array.from(summaries).some(
      (summary) => 
        form.id &&
        summary.dataset.errorSummaryFormIdValue === form.id
    )

    if (hasSummary) return
    
    const errors = form.querySelectorAll(ERROR_MESSAGE_SELECTOR)
    if (errors.length === 0) return

    const controls = Array.from(form.elements).filter(
      (control) => !(control instanceof HTMLFieldSetElement)
    )

    for (const error of errors) {
      if (!error.id) {
        console.error("Error summary: inline error is missing an ID", error)
        continue
      }

      const input = controls.find((control) => {
        const descriptionIds = (
          control.getAttribute("aria-describedby") || ""
        ).split(/\s+/)

        return (
          descriptionIds.includes(error.id) &&
          !control.matches(":disabled") &&
          isVisible(control)
        )
      })

      if (input) {
        input.focus()
        return
      }
    }

    console.error(
      "Error summary: no visible, enabled field is associated with the inline errors",
      form
    )
  }
}
