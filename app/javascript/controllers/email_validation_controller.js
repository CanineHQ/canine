import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "warning"]

  validate() {
    const email = this.inputTarget.value
    const domain = email.split("@")[1] || ""

    if (domain.endsWith("example.com")) {
      this.warningTarget.classList.remove("hidden")
    } else {
      this.warningTarget.classList.add("hidden")
    }
  }
}
