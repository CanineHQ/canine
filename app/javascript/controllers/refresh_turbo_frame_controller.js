import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    frequency: Number
  }

  connect() {
    // A frame that loads from its own src reloads from it; one rendered with the page reloads from the page
    this.refreshInterval = setInterval(() => {
      if (this.element.src) this.element.reload()
      else this.element.setAttribute("src", window.location.href)
    }, this.frequencyValue)
  }

  disconnect() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
    }
  }
}
