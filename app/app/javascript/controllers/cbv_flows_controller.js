import { Controller } from "@hotwired/stimulus"
import * as ActionCable from '@rails/actioncable'
import metaContent from "../utilities/meta";
import { loadPinwheel, initializePinwheel, fetchToken } from "../utilities/pinwheel"

export default class extends Controller {
  static targets = [
    "form",
    "searchTerms",
    "userAccountId",
    "modal"
  ];

  pinwheel = null;

  pinwheelUserToken = null;

  cable = ActionCable.createConsumer();

  connect() {
    // check for this value when connected
    this.pinwheelUserToken = metaContent('pinwheel_user_token');
    // this.cable.subscriptions.create({ channel: 'ArgylePaystubsChannel' }, {
    //   connected: () => {
    //     console.log("Connected to the channel:", this);
    //   },
    //   disconnected: () => {
    //     console.log("Disconnected");
    //   },
    //   received: (data) => {
    //     if (data.event === 'paystubs.fully_synced' || data.event === 'paystubs.partially_synced') {
    //       this.formTarget.submit();
    //     }
    //   }
    // });
  }

  onSignInSuccess(event) {
    this.userAccountIdTarget.value = event.accountId;
    this.pinwheel.close();
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
    loadPinwheel()
      .then(Pinwheel => initializePinwheel(Pinwheel, token, {
        onEvent: console.log,
      }))
      .then(pinwheel => this.pinwheel = pinwheel);
  }
}
