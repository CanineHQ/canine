import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    frequency: Number
  }

  connect() {
    console.log(this.frequencyValue)
    this.refreshInterval = setInterval(() => {
      console.log("Updating src");
      this.element.setAttribute("src", window.location.href);
    }, this.frequencyValue)
  }

  disconnect() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
    }
  }
}
