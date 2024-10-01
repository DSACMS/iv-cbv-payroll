import { Controller } from "@hotwired/stimulus"
import * as ActionCable from '@rails/actioncable'

export default class extends Controller {
  static targets = ["form", "userAccountId", "employmentJob", "identityJob", "paystubsJob", "incomeJob"];

  cable = ActionCable.createConsumer();

  updateIndicatorStatus(element, completed) {
    if (completed) {
      element.querySelector('.completed').classList.remove('display-none');
      element.querySelector('.in-progress').classList.add('display-none');
    } else {
      element.querySelector('.completed').classList.add('display-none');
      element.querySelector('.in-progress').classList.remove('display-none');
    }
  }

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

          this.updateIndicatorStatus(this.employmentJobTarget, data.employment);
          this.updateIndicatorStatus(this.identityJobTarget, data.identity);
          this.updateIndicatorStatus(this.paystubsJobTarget, data.paystubs);
          this.updateIndicatorStatus(this.incomeJobTarget, data.income);
        }
      }
    });
  }
}
