import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  connect() {
    this.update()
  }

  update() {
    const checkbox = this.element.querySelector("input[type=checkbox]")
    if (!checkbox || !this.hasContentTarget) return

    if (checkbox.checked) {
      this.contentTarget.classList.remove("hidden")
    } else {
      this.contentTarget.classList.add("hidden")
    }
  }
}
