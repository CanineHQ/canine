import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "dateInput"]

  connect() {
    this.updateExpiryDate()
  }

  updateExpiryDate() {
    const selectedOption = this.selectTarget.options[this.selectTarget.selectedIndex]
    const expiryValue = selectedOption.dataset.expiryValue
    if (expiryValue === "custom") {
      this.dateInputTarget.classList.remove("hidden")
    } else {
      this.dateInputTarget.classList.add("hidden")
    }

    if (!expiryValue || expiryValue === "custom") {
      this.setDateValue("");
    } else {
      const date = new Date(expiryValue);
      this.setDateValue(date.toISOString().slice(0, 10));
    }
  }

  setDateValue(value) {
    this.dateInputTarget.querySelector("input").value = value;
  }
}
