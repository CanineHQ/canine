import { Controller } from "@hotwired/stimulus"
import { PortainerChecker } from "../../utils/portainer"

export default class extends Controller {
  static targets = [
    "urlInput",
    "accessCodeInput",
    "accessCodeHelp",
    "verifyUrlSuccess",
    "verifyUrlError",
    "verifyUrlLoading",
    "errorMessage",
  ]

  async verifyUrl() {
    const url = this.urlInputTarget.value.trim()
    const accessCode = this.accessCodeInputTarget.value.trim()
    if (url) {
      this.accessCodeHelpTarget.querySelector('a').href = `${url.replace(/\/$/, '')}/#!/account`
      this.accessCodeHelpTarget.classList.remove('hidden')
    } else {
      this.accessCodeHelpTarget.classList.add('hidden')
    }

    if (!url || !accessCode) {
      return
    }

    this.hideAllStatuses()
    this.showLoading()

    const portainerChecker = new PortainerChecker()
    const result = await portainerChecker.verifyPortainerUrl(url, accessCode)
    if (result === PortainerChecker.STATUS_UNAUTHORIZED) {
      this.showError('The instance is reachable but the access code is invalid.')
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
