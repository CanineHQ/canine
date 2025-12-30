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

  getStackManagerType() {
    const selectElement = document.querySelector('select[name="stack_manager[stack_manager_type]"]')
    return selectElement ? selectElement.value : 'portainer'
  }

  async verifyUrl() {
    const url = this.urlInputTarget.value.trim()
    const accessToken = this.accessTokenInputTarget.value.trim()
    const stackManagerType = this.getStackManagerType()

    if (url) {
      // Update help link based on stack manager type
      const helpUrl = stackManagerType === 'rancher'
        ? `${url.replace(/\/$/, '')}/dashboard/account`
        : `${url.replace(/\/$/, '')}/#!/account`
      this.accessTokenHelpTarget.querySelector('a').href = helpUrl
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
    const result = await portainerChecker.verifyPortainerUrl(url, accessToken, stackManagerType)
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
