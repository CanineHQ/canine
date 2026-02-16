import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "card", "chartUrl", "repositoryUrl", "artifactHubPackageId"]

  connect() {
  }

  selectCard(event) {
    event.preventDefault()
    this.inputTarget.value = event.currentTarget.dataset.cardName
    this.cardTargets.forEach(card => card.classList.remove('ring', 'ring-primary'))
    event.currentTarget.classList.add('ring', 'ring-primary')

    // Show/hide forms based on selection
    this.element.querySelectorAll('.card-form').forEach(form => form.classList.add('hidden'))
    this.element.querySelectorAll(`.card-${event.currentTarget.dataset.cardName}`).forEach(form => form.classList.remove("hidden"))

    // Set chart URL (dispatch change for YAML autocomplete)
    if (this.hasChartUrlTarget && event.currentTarget.dataset.chartUrl) {
      this.chartUrlTarget.value = event.currentTarget.dataset.chartUrl
      this.chartUrlTarget.dispatchEvent(new Event('change'))
    }

    // Set repository URL for curated charts (no change event to avoid race condition)
    if (this.hasRepositoryUrlTarget && event.currentTarget.dataset.repositoryUrl) {
      this.repositoryUrlTarget.value = event.currentTarget.dataset.repositoryUrl
    }

    // Set artifact hub package ID for curated charts
    if (this.hasArtifactHubPackageIdTarget && event.currentTarget.dataset.artifactHubPackageId) {
      this.artifactHubPackageIdTarget.value = event.currentTarget.dataset.artifactHubPackageId
    }

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
}
