import { Controller } from "@hotwired/stimulus"
import * as ActionCable from '@rails/actioncable'
import { loadPinwheel, initializePinwheel, fetchToken } from "../../utilities/pinwheel"

export default class extends Controller {
  static targets = [
    "form",
    "searchTerms",
    "userAccountId",
    "modal"
  ];

  pinwheel = loadPinwheel();

  cable = ActionCable.createConsumer();

  connect() {
    this.cable.subscriptions.create({ channel: 'PaystubsChannel' }, {
      connected: () => {
        console.log("Connected to the channel:", this);
      },
      disconnected: () => {
        console.log("Disconnected");
      },
      received: (data) => {
        if (data.event === 'cbv.payroll_data_available') {
          const accountId = data.account_id
          this.userAccountIdTarget.value = accountId
          this.formTarget.submit();
        }
      }
    });
  }

  onSignInSuccess() {
    this.pinwheel.then(pinwheel => pinwheel.close());
    this.modalTarget.click();
  }

  onAccountError(event) {
    console.log(event);
  }

  async select(event) {
    const { responseType, id } = event.target.dataset;
    const { token } = await fetchToken(responseType, id);

    this.submit(token);
  }

  submit(token) {
    this.pinwheel.then(Pinwheel => initializePinwheel(Pinwheel, token, {
      onEvent: console.log,
      onSuccess: this.onSignInSuccess.bind(this),
    }));
  }
}
