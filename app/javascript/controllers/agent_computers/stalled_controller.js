import { Controller } from "@hotwired/stimulus"

// Swaps a running card's "working" bits for its "may be stuck" ones once nothing has happened for `after` seconds
// since `since` (the run's last progress); the card is re-rendered, and this reset, whenever the run moves again.
export default class extends Controller {
  static targets = ["working", "stuck"]
  static values = { since: String, after: Number }

  connect() {
    this.render()
    this.timer = setInterval(() => this.render(), 15000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  render() {
    const stuck = this.afterValue > 0 && (new Date() - new Date(this.sinceValue)) / 1000 >= this.afterValue
    this.workingTargets.forEach((el) => el.classList.toggle("hidden", stuck))
    this.stuckTargets.forEach((el) => el.classList.toggle("hidden", !stuck))
  }
}
