import { Controller } from "@hotwired/stimulus"
import * as ActionCable from '@rails/actioncable'

import metaContent from "../utilities/meta";
import { loadArgyle, initializeArgyle } from "../utilities/argyle"

function toOptionHTML({ value }) {
  return `<option value='${value}'>${value}</option>`;
}

export default class extends Controller {
  static targets = ["options", "continue", "userAccountId", "fullySynced", "form", "modal"];

  selection = null;

  argyle = null;

  argyleUserToken = null;

  cable = ActionCable.createConsumer();

  // TODO: information stored on the CbvFlow model can infer whether the paystubs are sync'd
  // by checking the value of payroll_data_available_from. We should make that the initial value.
  fullySynced = false;

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
        console.log("Received some data:", data);
        if (data.event === 'paystubs.fully_synced' || data.event === 'paystubs.partially_synced') {
          this.fullySynced = true;

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

  search(event) {
    const input = event.target.value;
    this.optionsTarget.innerHTML = [this.optionsTarget.innerHTML, toOptionHTML({ value: input })].join('');
  }

  select(event) {
    this.selection = event.detail;

    this.continueTarget.disabled = false;
  }

  submit(event) {
    event.preventDefault();

    loadArgyle()
      .then(Argyle => initializeArgyle(Argyle, this.argyleUserToken, {
        items: [this.selection.value],
        onAccountConnected: this.onSignInSuccess.bind(this),
        onAccountError: this.onAccountError.bind(this),
        // Unsure what these are for!
        onDDSSuccess: () => { console.log('onDDSSuccess') },
        onDDSError: () => { console.log('onDDSSuccess') },
        onTokenExpired: updateToken => { console.log('onTokenExpired') }
      }))
      .then(argyle => this.argyle = argyle)
      .then(() => this.argyle.open());
  }
}
