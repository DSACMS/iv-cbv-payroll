import { Controller } from "@hotwired/stimulus"

function toOptionHTML({ value }) {
  return `<option value='${value}'>${value}</option>`;
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

  connect() {
    if (this.hasOptionsTarget) {
      this.optionsTarget.innerHTML = DEFAULT_OPTIONS;
    }
  }

  search(event) {
    const input = event.target.value;
    this.optionsTarget.innerHTML = [...DEFAULT_OPTIONS, toOptionHTML({ value: input })].join('');
  }

  select(event) {
    console.log(event.detail);
    this.selection = event.detail;

    this.continueTarget.disabled = false;
  }
}
