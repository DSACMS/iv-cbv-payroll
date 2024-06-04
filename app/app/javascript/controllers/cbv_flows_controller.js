import { Controller } from "@hotwired/stimulus"
import * as ActionCable from '@rails/actioncable'

import metaContent from "../utilities/meta";

import { loadPinwheel, initializePinwheel } from "../utilities/pinwheel"
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

  select(event) {
    console.log(event.target.dataset);
    this.submit(event.target.dataset.itemId);
  }

  submit(itemId) {
    console.log(itemId);
    loadPinwheel()
      .then(Pinwheel => initializePinwheel(Pinwheel, this.pinwheelUserToken, {
        onEvent: console.log,
        // items: [itemId],
        // onAccountConnected: this.onSignInSuccess.bind(this),
        // onAccountError: this.onAccountError.bind(this),
        // // Unsure what these are for!
        // onDDSSuccess: () => { console.log('onDDSSuccess') },
        // onDDSError: () => { console.log('onDDSSuccess') },
        // onTokenExpired: updateToken,
      }))
      .then(pinwheel => this.pinwheel = pinwheel);
  }
}
