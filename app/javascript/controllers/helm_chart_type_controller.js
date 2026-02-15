import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chartType"]

  connect() {
    // Listen for radio button changes
    this.element.addEventListener('change', this.updateChartType.bind(this))
  }

  updateChartType(event) {
    // Check if it's a helm_source_type radio button
    if (event.target.name === 'helm_source_type') {
      this.chartTypeTarget.value = event.target.value
    }
  }
}
