import { Controller } from "@hotwired/stimulus"
import * as ActionCable from "@rails/actioncable"

export default class extends Controller {
  static targets = ["form", "userAccountId"]

  cable = ActionCable.createConsumer()

  connect() {
    this.cable.subscriptions.create(
      { channel: "PaystubsChannel", account_id: this.userAccountIdTarget.value },
      {
        connected: () => {
          console.log("Connected to the channel:", this)
        },
        disconnected: () => {
          console.log("Disconnected")
        },
        received: (data) => {
          if (data.event === "cbv.status_update") {
            if (data.has_fully_synced) {
              const accountId = data.account_id
              this.userAccountIdTarget.value = accountId
              this.formTarget.submit()
            }
          }
        },
      }
    )
  }
}
