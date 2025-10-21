import { Controller } from "@hotwired/stimulus"
import * as ActionCable from "@rails/actioncable"

export default class extends Controller {
  static values = {
    dataSourceUrl: String,
    cbvFlowId: Number,
  }

  cable = ActionCable.createConsumer()

  connect() {}

  async initialize() {
    window.open(this.dataSourceUrlValue, "_blank")
    this.cable.subscriptions.create(
      { channel: "DataSourceChannel", cbv_flow_id: this.cbvFlowIdValue },
      {
        connected: () => {
          console.log("Connected to the channel:", this)
          console.log("cbv_flow_id", this.cbvFlowIdValue)
        },
        disconnected: () => {
          console.log("Disconnected")
        },
        received: (data) => {
          const btn = document.getElementById("next-button")
          btn.disabled = false
        },
      }
    )
  }
}
