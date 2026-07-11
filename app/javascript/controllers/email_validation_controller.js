import { Controller } from "@hotwired/stimulus"

const BANNED_DOMAINS = ["example.com", "example.org", "example.net", "test.com"]

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.warning = document.createElement("p")
    this.warning.className = "text-warning text-sm mt-1 hidden"
    this.warning.textContent = "Avoid using this domain — Let's Encrypt will reject certificate requests for it."
    this.inputTarget.parentNode.appendChild(this.warning)
  }

  validate() {
    const domain = (this.inputTarget.value.split("@")[1] || "").toLowerCase()
    const banned = BANNED_DOMAINS.some(d => domain === d || domain.endsWith(`.${d}`))

    this.warning.classList.toggle("hidden", !banned)
  }
}
