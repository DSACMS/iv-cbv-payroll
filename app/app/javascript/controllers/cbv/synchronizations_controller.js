import { Controller } from "@hotwired/stimulus"
import * as ActionCable from '@rails/actioncable'

export default class extends Controller {
  static targets = ["form", "userAccountId", "employmentJob", "identityJob", "paystubsJob", "incomeJob"];

  cable = ActionCable.createConsumer();

  connect() {
    this.cable.subscriptions.create({ channel: 'PaystubsChannel', account_id: this.userAccountIdTarget.value }, {
      connected: () => {
        console.log("Connected to the channel:", this);
      },
      disconnected: () => {
        console.log("Disconnected");
      },
      received: (data) => {
        if (data.event === 'cbv.status_update') {
          if (data.has_fully_synced) {
            const accountId = data.account_id;
            this.userAccountIdTarget.value = accountId;
            this.formTarget.submit();
          }

          this.employmentJobTarget.textContent = data.employment;
          this.identityJobTarget.textContent = data.identity;
          this.paystubsJobTarget.textContent = data.paystubs;
          this.incomeJobTarget.textContent = data.income;
        }
      }
    });
  }
}
