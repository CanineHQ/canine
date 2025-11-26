import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    this.containerTarget.classList.add("hidden", "opacity-0", "transition-all")
  }

  show(e) {
    e.preventDefault();

    e.target.classList.add("hidden")
    this.containerTarget.classList.remove("hidden", "opacity-0")
    this.containerTarget.classList.add("opacity-100", "duration-500")
  }
}