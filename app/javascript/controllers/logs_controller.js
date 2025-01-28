import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    console.log("connected")
    // Scroll to the bottom of the container
    this.scrollToBottom();

    // Add event listener for Turbo Frame load
    document.addEventListener('turbo:frame-load', this.scrollToBottom.bind(this));
  }

  scrollToBottom() {
    this.containerTarget.scrollTop = this.containerTarget.scrollHeight;
  }
}
