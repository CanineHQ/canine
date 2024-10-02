import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "card"]
  static values = { repository: String }

  connect() {
    console.log("HelmChartSelector controller connected")
  }

  selectChart(event) {
    event.preventDefault()
    this.inputTarget.value = event.currentTarget.dataset.chartName
    this.cardTargets.forEach(card => card.classList.remove('ring', 'ring-primary'))
    event.currentTarget.classList.add('ring', 'ring-primary')
    // Show Input
    this.element.querySelectorAll('.chart-form').forEach(form => form.classList.add('hidden'))
    document.getElementById(`chart-${event.currentTarget.dataset.chartName}`).classList.remove("hidden");
  }
}