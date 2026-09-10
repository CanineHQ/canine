import { Controller } from "@hotwired/stimulus"
import { debounce } from "../../utils"

export default class extends Controller {
  static targets = [
    "ociUrl",
    "loading",
    "error",
    "errorMessage"
  ]

  connect() {
    this.debouncedFetchVersions = debounce(this.fetchVersions.bind(this), 500)
  }

  onInput() {
    const ociUrl = this.ociUrlTarget.value.trim()

    // Set the repository_url hidden field
    const repositoryUrlInput = document.querySelector('input[name="add_on[repository_url]"]')
    if (repositoryUrlInput) {
      repositoryUrlInput.value = ociUrl
    }

    // Set chart_url from OCI URL path (e.g., oci://ghcr.io/org/repo/chart -> org-repo/chart)
    const chartUrlInput = document.querySelector('input[name="add_on[chart_url]"]')
    if (chartUrlInput && ociUrl.startsWith('oci://')) {
      const parts = ociUrl.replace('oci://', '').split('/').filter(p => p.length > 0)
      if (parts.length >= 2) {
        const chartName = parts[parts.length - 1]
        const repoAlias = parts.slice(1, -1).join('-') || parts[0].replace(/\./g, '-')
        chartUrlInput.value = `${repoAlias}/${chartName}`
        chartUrlInput.dispatchEvent(new Event('change'))
      }
    }

    this.debouncedFetchVersions()
  }

  async fetchVersions() {
    const ociUrl = this.ociUrlTarget.value.trim()

    if (!ociUrl) {
      return
    }

    // Validate OCI URL format
    if (!ociUrl.startsWith('oci://')) {
      this.showError("URL must start with oci://")
      return
    }

    const parts = ociUrl.replace('oci://', '').split('/').filter(p => p.length > 0)
    if (parts.length < 2) {
      this.showError("Invalid OCI URL format")
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
        body: JSON.stringify({ repo_url: ociUrl })
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to fetch OCI tags')
      }

      const data = await response.json()
      const versions = Object.values(data.charts)[0]

      if (versions && versions.length > 0) {
        // Populate the version selector directly
        const versionSelectorController = this.application.getControllerForElementAndIdentifier(
          document.querySelector('[data-controller*="add-ons--version-selector"]'),
          'add-ons--version-selector'
        )
        if (versionSelectorController) {
          versionSelectorController.populateVersionSelector(versions)
          versionSelectorController.showVersionSelector()
          versionSelectorController.enableSubmitButton()
        }
        this.hideLoading()
      } else {
        throw new Error('No versions found in OCI registry')
      }
    } catch (error) {
      this.hideLoading()
      this.showError(error.message)
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
}
