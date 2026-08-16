import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["webhookUrl"]

  connect() {
    this.toggle()
    document.addEventListener("change", this.handleChange)
  }

  disconnect() {
    document.removeEventListener("change", this.handleChange)
  }

  handleChange = (event) => {
    if (event.target.name === "notifier[provider_type]") {
      this.toggle()
    }
  }

  toggle() {
    const selected = document.querySelector('input[name="notifier[provider_type]"]:checked')
    if (selected && this.hasWebhookUrlTarget) {
      this.webhookUrlTarget.classList.toggle("hidden", selected.value === "email")
    }
  }
}
