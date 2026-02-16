import AsyncSearchDropdownController from "../components/async_search_dropdown_controller"
import { renderHelmChartCard, helmChartHeader } from "../../utils/helm_charts"

export default class extends AsyncSearchDropdownController {
  static values = {
    chartName: String
  }

  getInputElement() {
    return this.element.querySelector(`input[name="add_on[metadata][helm_chart][helm_chart.name]"]`)
  }

  async fetchResults(query) {
    const response = await fetch(`/add_ons/search?q=${encodeURIComponent(query)}`)
    if (!response.ok) {
      throw new Error('Failed to fetch helm charts')
    }
    const data = await response.json()
    return data.packages
  }

  renderItem(pkg) {
    return helmChartHeader(pkg)
  }

  onItemSelect(pkg) {
    this.input.parentElement.classList.add('hidden')
    this.input.value = pkg.name
    const chartUrl = `${pkg.repository.name}/${pkg.name}`

    // Set chart_url (dispatch change for YAML autocomplete)
    const chartUrlInput = document.querySelector(`input[name="add_on[chart_url]"]`)
    chartUrlInput.value = chartUrl
    chartUrlInput.dispatchEvent(new Event('change'))

    // Set repository_url (no change event to avoid race condition)
    const repositoryUrlInput = document.querySelector(`input[name="add_on[repository_url]"]`)
    repositoryUrlInput.value = pkg.repository.url

    // Set artifact_hub_package_id (format: helm/repo/chart)
    const artifactHubPackageIdInput = document.querySelector(`input[name="add_on[artifact_hub_package_id]"]`)
    artifactHubPackageIdInput.value = `helm/${chartUrl}`

    this.element.appendChild(renderHelmChartCard(pkg))

    // Trigger version fetch after all fields are set
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

  clearSelection() {
    // Remove the card
    const card = this.element.querySelector('[data-helm-chart-card]')
    if (card) {
      card.remove()
    }

    // Clear the chart_url
    const chartUrlInput = document.querySelector(`input[name="add_on[chart_url]"]`)
    if (chartUrlInput) {
      chartUrlInput.value = ''
      chartUrlInput.dispatchEvent(new Event('change'))
    }

    // Clear repository_url
    const repositoryUrlInput = document.querySelector(`input[name="add_on[repository_url]"]`)
    if (repositoryUrlInput) {
      repositoryUrlInput.value = ''
    }

    // Clear artifact_hub_package_id
    const artifactHubPackageIdInput = document.querySelector(`input[name="add_on[artifact_hub_package_id]"]`)
    if (artifactHubPackageIdInput) {
      artifactHubPackageIdInput.value = ''
    }

    // Clear and show the input
    this.input.value = ''
    this.input.parentElement.classList.remove('hidden')
    this.input.focus()
  }
}