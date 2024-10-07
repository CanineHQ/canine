import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "card"]
  static values = { repository: String }

  connect() {
  }

  selectCard(event) {
    event.preventDefault()
    this.inputTarget.value = event.currentTarget.dataset.cardName
    this.cardTargets.forEach(card => card.classList.remove('ring', 'ring-primary'))
    event.currentTarget.classList.add('ring', 'ring-primary')
    // Show Input
    this.element.querySelectorAll('.card-form').forEach(form => form.classList.add('hidden'))
    this.element.querySelector(`#card-${event.currentTarget.dataset.cardName}`)?.classList.remove("hidden");
  }
}