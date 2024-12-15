import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["instructions"]

  update(event) {
    // Validate it is a valid IP address
    if (!/^(\d{1,3}\.){3}\d{1,3}$/.test(event.target.value)) {
      return
    }
    this.instructionsTarget.classList.remove("hidden")
  }
}

