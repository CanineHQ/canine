import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "icon"]

  toggle() {
    if (this.inputTarget.type === "password") {
      this.inputTarget.type = "text"
      this.iconTarget.setAttribute("icon", "mdi:eye-off")
    } else {
      this.inputTarget.type = "password"
      this.iconTarget.setAttribute("icon", "mdi:eye")
    }
  }
}
