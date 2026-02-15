import { Controller } from "@hotwired/stimulus"
import { debounce } from "../utils"

export default class extends Controller {
  static targets = [
    "repoUrl",
    "loading",
    "error",
    "errorMessage",
    "chartSelector",
    "chartSelect",
    "versionSelector",
    "versionSelect"
  ]

  connect() {
    this.charts = {}
    this.debouncedFetchCharts = debounce(this.fetchCharts.bind(this), 500)
  }

  onInput() {
    this.debouncedFetchCharts()
  }

  async fetchCharts() {
    const repoUrl = this.repoUrlTarget.value.trim()

    if (!repoUrl) {
      this.hideChartSelector()
      return
    }

    // Validate URL format
    try {
      new URL(repoUrl)
    } catch (e) {
      this.showError("Please enter a valid URL")
      return
    }

    this.showLoading()
    this.hideError()

    try {
      const response = await fetch('/add_ons/fetch_helm_repository_index', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ repo_url: repoUrl })
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to fetch repository index')
      }

      const data = await response.json()
      this.charts = data.charts
      this.populateChartSelector()
      this.hideLoading()
      this.showChartSelector()
    } catch (error) {
      this.hideLoading()
      this.showError(error.message)
      this.hideChartSelector()
    }
  }

  populateChartSelector() {
    // Clear existing options
    this.chartSelectTarget.innerHTML = '<option value="">Select a chart...</option>'

    // Add chart options
    Object.keys(this.charts).sort().forEach(chartName => {
      const option = document.createElement('option')
      option.value = chartName
      option.textContent = chartName
      this.chartSelectTarget.appendChild(option)
    })
  }

  onChartChange() {
    const selectedChart = this.chartSelectTarget.value

    if (!selectedChart) {
      this.hideVersionSelector()
      return
    }

    const versions = this.charts[selectedChart]

    // Clear existing options
    this.versionSelectTarget.innerHTML = '<option value="">Latest version</option>'

    // Add version options (sorted by version, newest first)
    versions.forEach(version => {
      const option = document.createElement('option')
      option.value = version
      option.textContent = version
      this.versionSelectTarget.appendChild(option)
    })

    this.showVersionSelector()
  }

  showLoading() {
    this.loadingTarget.classList.remove('hidden')
  }

  hideLoading() {
    this.loadingTarget.classList.add('hidden')
  }

  showError(message) {
    this.errorMessageTarget.textContent = message
    this.errorTarget.classList.remove('hidden')
  }

  hideError() {
    this.errorTarget.classList.add('hidden')
  }

  showChartSelector() {
    this.chartSelectorTarget.classList.remove('hidden')
  }

  hideChartSelector() {
    this.chartSelectorTarget.classList.add('hidden')
    this.hideVersionSelector()
  }

  showVersionSelector() {
    this.versionSelectorTarget.classList.remove('hidden')
  }

  hideVersionSelector() {
    this.versionSelectorTarget.classList.add('hidden')
  }
}
