import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const progress = this.element;
    let value = 0;

    this.interval = setInterval(() => {
      value = (value + 1) % 101;
      progress.value = value;
    }, 15);
  }

  disconnect() {
    clearInterval(this.interval);
  }
}
