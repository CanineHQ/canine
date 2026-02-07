import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "icon"]
  static values = { maskLength: { type: Boolean, default: false } }

  connect() {
    if (this.maskLengthValue) {
      this.realValue = this.inputTarget.value
      this.inputTarget.value = "••••••••••••••••"
      this.inputTarget.type = "text"
      this.masked = true
    }
  }

  toggle() {
    if (this.maskLengthValue) {
      if (this.masked) {
        this.inputTarget.value = this.realValue
        this.iconTarget.setAttribute("icon", "mdi:eye-off")
      } else {
        this.inputTarget.value = "••••••••••••••••"
        this.iconTarget.setAttribute("icon", "mdi:eye")
      }
      this.masked = !this.masked
    } else {
      if (this.inputTarget.type === "password") {
        this.inputTarget.type = "text"
        this.iconTarget.setAttribute("icon", "mdi:eye-off")
      } else {
        this.inputTarget.type = "password"
        this.iconTarget.setAttribute("icon", "mdi:eye")
      }
    }
  }
}
