import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const progress = this.element;
    let value = 0;
    
    setInterval(() => {
      value = (value + 1) % 101;
      progress.value = value;
    }, 15);
  }
}
