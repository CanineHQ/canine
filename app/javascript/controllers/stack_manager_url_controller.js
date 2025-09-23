import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["urlInput", "verifyUrlSuccess", "verifyUrlError", "verifyUrlLoading", "errorMessage"]

  connect() {
    if (this.urlInputTarget.value) {
      this.verifyUrl()
    }
  }

  async verifyUrl(event) {
    const url = this.urlInputTarget.value.trim()
    
    if (!url) {
      this.hideAllStatuses()
      return
    }

    this.showLoading()

    try {
      const response = await fetch('/stack_manager/verify_url', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ url: url })
      })

      const data = await response.json()

      if (data.success) {
        this.showSuccess()
      } else {
        this.showError(data.message || 'Unable to connect to Portainer')
      }
    } catch (error) {
      this.showError('Network error - please check the URL')
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
    if (this.hasErrorMessageTarget && message) {
      this.errorMessageTarget.textContent = message
    }
    this.verifyUrlErrorTarget.classList.remove('hidden')
  }

  hideAllStatuses() {
    this.verifyUrlSuccessTarget.classList.add('hidden')
    this.verifyUrlErrorTarget.classList.add('hidden')
    this.verifyUrlLoadingTarget.classList.add('hidden')
  }
}
