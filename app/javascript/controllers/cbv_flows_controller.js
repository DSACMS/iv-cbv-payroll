import { Controller } from "@hotwired/stimulus"

import metaContent from "../utilities/meta";
import { loadArgyle, initializeArgyle } from "../utilities/argyle"

function toOptionHTML({ value }) {
  return `<option value='${value}'>${value}</option>`;
}

export default class extends Controller {
  static targets = ["options", "continue", "userAccountId"];

  selection = null;

  argyle = null;

  argyleUserToken = null;

  connect() {
    // check for this value when connected
    this.argyleUserToken = metaContent('argyle_user_token');
  }

  onSignInSuccess(event) {
    this.userAccountIdTarget.value = event.accountId;

    this.element.submit();
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
