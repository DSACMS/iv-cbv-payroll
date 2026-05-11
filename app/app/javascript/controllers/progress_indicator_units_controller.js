import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "unitContent"]
  static values = { unit: String }

  connect() {
    this.render()
  }

  toggle(event) {
    const wasFocused = this.toggleTargets.includes(document.activeElement)
    this.unitValue = event.currentTarget.dataset.nextUnit
    this.render()
    if (wasFocused) {
      this.toggleTargets.find((toggle) => !toggle.hidden)?.focus()
    }
  }

  render() {
    this.toggleTargets.forEach((toggle) => {
      toggle.hidden = toggle.dataset.unit !== this.unitValue
    })

    this.unitContentTargets.forEach((content) => {
      content.hidden = content.dataset.unit !== this.unitValue
    })
  }
}
