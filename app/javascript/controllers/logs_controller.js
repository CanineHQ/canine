import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"

const REFRESH_INTERVAL = 4000;
export default class extends Controller {
  static targets = ["container"]
  static values = {
    url: String
  }

  connect() {
    // Scroll to the bottom of the container
    this.scrollToBottom();

    // Add event listener for Turbo Frame load
    document.addEventListener('turbo:frame-load', this.scrollToBottom.bind(this));
    this.interval = setInterval(() => {
      // Fetch new logs
      this.loadNewLogs();
    }, REFRESH_INTERVAL);
  }

  disconnect() {
    clearInterval(this.interval);
  }

  async loadNewLogs() {
    // Only do this if the scroll is at the bottom
    if (this.containerTarget.scrollTop === (this.containerTarget.scrollHeight - this.containerTarget.offsetHeight)) {
      await get(this.urlValue, {
        responseKind: 'turbo-stream'
      });
      this.scrollToBottom();
    }
  }

  scrollToBottom() {
    this.containerTarget.scrollTop = this.containerTarget.scrollHeight;
  }
}
