import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"

const REFRESH_INTERVAL = 4000;
export default class extends Controller {
  static targets = ["container"]
  static values = {
    url: String
  }

  connect() {
    this.scrollToBottom();

    this.boundScrollToBottom = this.scrollToBottom.bind(this);
    document.addEventListener('turbo:frame-load', this.boundScrollToBottom);
    this.interval = setInterval(() => {
      this.loadNewLogs();
    }, REFRESH_INTERVAL);
  }

  disconnect() {
    clearInterval(this.interval);
    document.removeEventListener('turbo:frame-load', this.boundScrollToBottom);
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
