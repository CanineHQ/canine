import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["repositoryUrl", "chartUrl", "versionSelector", "versionSelect", "loading", "error", "errorMessage", "submitButton"]

  connect() {
    // Version fetching is triggered directly by other controllers
    // to avoid race conditions when both fields are updated
  }

  async fetchVersions() {
    const repositoryUrl = this.repositoryUrlTarget.value
    const chartUrl = this.chartUrlTarget.value

    console.log('Fetching versions...', { repositoryUrl, chartUrl })

    if (!repositoryUrl || !chartUrl) {
      console.log('Missing repository URL or chart URL, skipping version fetch')
      this.hideVersionSelector()
      return
    }

    // Disable submit button while fetching
    this.disableSubmitButton()

    this.showLoading()
    this.hideError()

    try {
      const response = await fetch('/add_ons/fetch_helm_repository_index', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ repo_url: repositoryUrl })
      })

      if (!response.ok) {
        throw new Error('Failed to fetch repository index')
      }

      const data = await response.json()
      const chartName = chartUrl.split('/').pop()
      const versions = data.charts[chartName]

      if (versions && versions.length > 0) {
        this.populateVersionSelector(versions)
        this.hideLoading()
        this.showVersionSelector()
        this.enableSubmitButton()
      } else {
        throw new Error(`Chart "${chartName}" not found in repository`)
      }
    } catch (error) {
      this.hideLoading()
      this.showError(error.message)
      this.hideVersionSelector()
      this.enableSubmitButton()
    }
  }

  disableSubmitButton() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add('btn-disabled')
    }
  }

  enableSubmitButton() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove('btn-disabled')
    }
  }

  populateVersionSelector(versions) {
    this.versionSelectTarget.innerHTML = ''

    // Add "Latest" option (first version)
    const latestOption = document.createElement('option')
    latestOption.value = versions[0]
    latestOption.textContent = `${versions[0]} (Latest)`
    latestOption.selected = true
    this.versionSelectTarget.appendChild(latestOption)

    // Add other versions
    versions.slice(1).forEach(version => {
      const option = document.createElement('option')
      option.value = version
      option.textContent = version
      this.versionSelectTarget.appendChild(option)
    })
  }

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove('hidden')
    }
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add('hidden')
    }
  }

  showError(message) {
    if (this.hasErrorTarget && this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
      this.errorTarget.classList.remove('hidden')
    }
  }

  hideError() {
    if (this.hasErrorTarget) {
      this.errorTarget.classList.add('hidden')
    }
  }

  showVersionSelector() {
    if (this.hasVersionSelectorTarget) {
      this.versionSelectorTarget.classList.remove('hidden')
    }
  }

  hideVersionSelector() {
    if (this.hasVersionSelectorTarget) {
      this.versionSelectorTarget.classList.add('hidden')
    }
  }
}
