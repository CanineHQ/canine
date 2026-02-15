import { Controller } from "@hotwired/stimulus"
import { debounce } from "../../utils"

export default class extends Controller {
  static targets = [
    "repoUrl",
    "loading",
    "error",
    "errorMessage",
    "chartSelector",
    "chartSelect"
  ]

  connect() {
    this.charts = {}
    this.debouncedFetchCharts = debounce(this.fetchCharts.bind(this), 500)
  }

  onInput() {
    // Sync the display field with the actual hidden repository_url field (no change event)
    const repoUrl = this.repoUrlTarget.value.trim()
    const repositoryUrlInput = document.querySelector('input[name="add_on[repository_url]"]')
    if (repositoryUrlInput) {
      repositoryUrlInput.value = repoUrl
    }

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
      return
    }

    // Set the chart_url input (format: repo/chart_name)
    const chartUrlInput = document.querySelector('input[name="add_on[chart_url]"]')
    if (chartUrlInput) {
      chartUrlInput.value = selectedChartUrl
      chartUrlInput.dispatchEvent(new Event('change'))
    }

    // Trigger version fetch after chart is selected
    this.triggerVersionFetch()
  }

  triggerVersionFetch() {
    const versionSelectorController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller*="add-ons--version-selector"]'),
      'add-ons--version-selector'
    )
    if (versionSelectorController) {
      versionSelectorController.fetchVersions()
    }
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
  }
}
