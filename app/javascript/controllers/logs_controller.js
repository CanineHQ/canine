import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    // Scroll to the bottom of the container
    this.containerTarget.scrollTop = this.containerTarget.scrollHeight;
    console.log("Logs controller connected")
  }
}
