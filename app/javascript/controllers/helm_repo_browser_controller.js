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

  // Extract repository alias from URL
  // e.g., "https://czhu12.github.io/openclaw-helm" -> "openclaw-helm"
  getRepoAlias(repoUrl) {
    try {
      const url = new URL(repoUrl)
      const pathParts = url.pathname.split('/').filter(p => p.length > 0)
      return pathParts[pathParts.length - 1] || url.hostname.replace(/\./g, '-')
    } catch (e) {
      return 'custom-repo'
    }
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
    const repoUrl = this.repoUrlTarget.value.trim()
    const repoAlias = this.getRepoAlias(repoUrl)

    // Clear existing options
    this.chartSelectTarget.innerHTML = '<option value="">Select a chart...</option>'

    // Add chart options with repo-alias/chart-name format
    Object.keys(this.charts).sort().forEach(chartName => {
      const option = document.createElement('option')
      option.value = `${repoAlias}/${chartName}`
      option.textContent = chartName
      option.dataset.chartName = chartName
      this.chartSelectTarget.appendChild(option)
    })
  }

  onChartChange() {
    const selectedChartUrl = this.chartSelectTarget.value

    if (!selectedChartUrl) {
      this.hideVersionSelector()
      return
    }

    // Extract the actual chart name from the selected option
    const selectedOption = this.chartSelectTarget.options[this.chartSelectTarget.selectedIndex]
    const chartName = selectedOption.dataset.chartName
    const versions = this.charts[chartName]

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
