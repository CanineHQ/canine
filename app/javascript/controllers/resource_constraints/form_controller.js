import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  toggleResourceConstraints(event) {
    if (event.target.checked) {
      this.containerTarget.classList.remove("hidden")
    } else {
      this.containerTarget.classList.add("hidden")
    }
  }
}
