import { Controller } from "@hotwired/stimulus"
import * as ActionCable from '@rails/actioncable'
import { loadPinwheel, initializePinwheel, fetchToken } from "../../utilities/pinwheel"

export default class extends Controller {
  static targets = [
    "form",
    "searchTerms",
    "userAccountId",
    "modal",
    "employerButton"
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
    this.errorHandler = document.addEventListener("turbo:frame-missing", this.onTurboError)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-missing", this.errorHandler)
  }

  onSignInSuccess() {
    this.pinwheel.then(pinwheel => pinwheel.close());
    this.modalTarget.click();
    this.reenableButtons()
  }

  onTurboError(event) {
    console.warn("Got turbo error, redirecting:", event)

    const location = event.detail.response.url
    event.detail.visit(location)
    event.preventDefault()
  }

  async select(event) {
    const { responseType, id } = event.target.dataset;
    this.disableButtons()

    const { token } = await fetchToken(responseType, id);
    this.submit(token);
  }

  submit(token) {
    this.pinwheel.then(Pinwheel => initializePinwheel(Pinwheel, token, {
      onEvent: console.log,
      onExit: this.reenableButtons.bind(this),
      onSuccess: this.onSignInSuccess.bind(this),
    }));
  }

  disableButtons() {
    this.employerButtonTargets
      .forEach(el => el.setAttribute("disabled", "disabled"))
  }

  reenableButtons() {
    this.employerButtonTargets
      .forEach(el => el.removeAttribute("disabled"))
  }
}
