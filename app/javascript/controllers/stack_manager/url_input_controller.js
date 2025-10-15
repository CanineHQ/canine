import { Controller } from "@hotwired/stimulus"
import { PortainerChecker } from "../../utils/portainer"

export default class extends Controller {
  static targets = [
    "urlInput",
    "accessTokenInput",
    "accessTokenHelp",
    "verifyUrlSuccess",
    "verifyUrlError",
    "verifyUrlLoading",
    "errorMessage",
  ]

  async verifyUrl() {
    const url = this.urlInputTarget.value.trim()
    const accessToken = this.accessTokenInputTarget.value.trim()
    if (url) {
      this.accessTokenHelpTarget.querySelector('a').href = `${url.replace(/\/$/, '')}/#!/account`
      this.accessTokenHelpTarget.classList.remove('hidden')
    } else {
      this.accessTokenHelpTarget.classList.add('hidden')
    }

    if (!url || !accessToken) {
      return
    }

    this.hideAllStatuses()
    this.showLoading()

    const portainerChecker = new PortainerChecker()
    const result = await portainerChecker.verifyPortainerUrl(url, accessToken)
    if (result === PortainerChecker.STATUS_UNAUTHORIZED) {
      this.showError('The instance is reachable but the access token is invalid.')
    } else if (result === PortainerChecker.STATUS_OK) {
      this.showSuccess()
    } else {
      this.showError('Unable to connect to the instance. Please check the URL.')
    }
  }

  showLoading() {
    this.hideAllStatuses()
    this.verifyUrlLoadingTarget.classList.remove('hidden')
  }

  showSuccess() {
    this.hideAllStatuses()
    this.verifyUrlSuccessTarget.classList.remove('hidden')
  }

  showError(message) {
    this.hideAllStatuses()
    this.errorMessageTarget.textContent = message
    this.verifyUrlErrorTarget.classList.remove('hidden')
  }

  hideAllStatuses() {
    this.verifyUrlSuccessTarget.classList.add('hidden')
    this.verifyUrlErrorTarget.classList.add('hidden')
    this.verifyUrlLoadingTarget.classList.add('hidden')
  }
}
