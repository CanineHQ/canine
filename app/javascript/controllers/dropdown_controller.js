import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["trigger"];

  connect() {
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this);
    document.addEventListener("click", this.closeOnClickOutside);
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnClickOutside);
  }

  toggle(event) {
    event.preventDefault();
    this.element.classList.toggle("dropdown-open");
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.element.classList.remove("dropdown-open");
    }
  }

  close() {
    this.element.classList.remove("dropdown-open");
  }
}
