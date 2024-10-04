import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "icon"]

  toggle() {
    if (this.inputTarget.type === "password") {
      this.inputTarget.type = "text"
      this.iconTarget.classList.replace("bi-eye", "bi-eye-slash")
    } else {
      this.inputTarget.type = "password"
      this.iconTarget.classList.replace("bi-eye-slash", "bi-eye")
    }
  }
}
