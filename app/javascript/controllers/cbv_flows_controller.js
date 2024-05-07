import { Controller } from "@hotwired/stimulus"
import * as ActionCable from '@rails/actioncable'

import metaContent from "../utilities/meta";
import { loadArgyle, initializeArgyle, updateToken } from "../utilities/argyle"

export default class extends Controller {
  static targets = [
    "form",
    "searchTerms",
    "userAccountId",
    "modal"
  ];

  argyle = null;

  argyleUserToken = null;

  cable = ActionCable.createConsumer();

  connect() {
    // check for this value when connected
    this.argyleUserToken = metaContent('argyle_user_token');
    this.cable.subscriptions.create({ channel: 'ArgylePaystubsChannel' }, {
      connected: () => {
        console.log("Connected to the channel:", this);
      },
      disconnected: () => {
        console.log("Disconnected");
      },
      received: (data) => {
        if (data.event === 'paystubs.fully_synced' || data.event === 'paystubs.partially_synced') {
          this.formTarget.submit();
        }
      }
    });
  }

  onSignInSuccess(event) {
    this.userAccountIdTarget.value = event.accountId;
    this.argyle.close();
    this.modalTarget.click();
  }

  onAccountError(event) {
    console.log(event);
  }

  select(event) {
    this.submit(event.target.dataset.itemId);
  }

  submit(itemId) {
    loadArgyle()
      .then(Argyle => initializeArgyle(Argyle, this.argyleUserToken, {
        items: [itemId],
        onAccountConnected: this.onSignInSuccess.bind(this),
        onAccountError: this.onAccountError.bind(this),
        // Unsure what these are for!
        onDDSSuccess: () => { console.log('onDDSSuccess') },
        onDDSError: () => { console.log('onDDSSuccess') },
        onTokenExpired: updateToken,
      }))
      .then(argyle => this.argyle = argyle)
      .then(() => this.argyle.open());
  }
}
