import { Controller } from "@hotwired/stimulus"
import loadScript from 'load-script';

import metaContent from "../utilities/meta";

function toOptionHTML({ value }) {
  return `<option value='${value}'>${value}</option>`;
}

function loadArgyle() {
  return new Promise((resolve, reject) => {
    loadScript('https://plugin.argyle.com/argyle.web.v5.js', (err, script) => {
      if (err) {
        reject(err);
      } else {
        resolve(Argyle);
      }
    });
  });
}

function initializeArgyle(Argyle, userToken, callbacks) {
  return Argyle.create({
    userToken,
    sandbox: true, // Set to false for production environment.
    ...callbacks
  });
}

const DEFAULT_OPTIONS = [
  {
    value: 'Uber'
  },
  {
    value: 'Instacart'
  },
  {
    value: 'Walmart'
  },
  {
    value: 'Lyft'
  }
].map(toOptionHTML);

export default class extends Controller {
  static targets = ["options", "continue"];

  selection = null;

  argyle = null;

  connect() {
    const argyleUserToken = metaContent('argyle_user_token');

    loadArgyle()
      .then(Argyle => initializeArgyle(Argyle, argyleUserToken, {
        onAccountConnected: this.onArgyleEvent.bind(this),
        onAccountError: this.onArgyleEvent.bind(this),
        onDDSSuccess: this.onArgyleEvent.bind(this),
        onDDSError: this.onArgyleEvent.bind(this),
        onTokenExpired: updateToken => { console.log('onTokenExpired') }
      }))
      .then(argyle => this.argyle = argyle);

    if (this.hasOptionsTarget) {
      this.optionsTarget.innerHTML = DEFAULT_OPTIONS;
    }
  }

  // general event for when anything happens in the flow
  onArgyleEvent() {
    this.element.submit();
  }

  search(event) {
    const input = event.target.value;
    this.optionsTarget.innerHTML = [...DEFAULT_OPTIONS, toOptionHTML({ value: input })].join('');
  }

  select(event) {
    this.selection = event.detail;

    this.continueTarget.disabled = false;
  }

  submit(event) {
    event.preventDefault();

    this.argyle.open();
  }
}
