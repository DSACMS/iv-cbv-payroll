import { Controller } from "@hotwired/stimulus"

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

    form.querySelectorAll(".usa-error-message").forEach((error) => {
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
    const summaries = document.querySelectorAll(
      '[data-controller~="error-summary"][data-error-summary-form-id-value]'
    )

    const hasSummary = Array.from(summaries).some(
      (summary) => 
        form.id &&
        summary.dataset.errorSummaryFormIdValue === form.id
    )

    if (hasSummary) return
    
    const errors = form.querySelectorAll(".usa-error-message")
    if (errors.length === 0) return

    const controls = Array.from(form.elements)

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
          control.getClientRects().length > 0
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
