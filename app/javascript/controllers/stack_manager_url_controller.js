import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["urlInput", "verifyUrlSuccess", "verifyUrlError", "verifyUrlLoading", "errorMessage"]
  static values = {
    verifyUrl: String,
    logoutOnFailure: Boolean
  }

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
      const response = await fetch(this.verifyUrlValue, {
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
        if (this.logoutOnFailureValue) {
          await this.logout()
        }
      }
    } catch (error) {
      this.showError('Network error - please check the URL')
      if (this.logoutOnFailureValue) {
        await this.logout()
      }
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

  async logout() {
    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      const response = await fetch('/users/sign_out', {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': csrfToken,
          'Accept': 'text/vnd.turbo-stream.html, text/html, application/xhtml+xml',
          'X-Requested-With': 'XMLHttpRequest'
        },
        credentials: 'same-origin'
      })

      if (response.ok) {
        window.location.href = '/users/sign_in'
      }
    } catch (error) {
      console.error('Logout failed:', error)
      window.location.href = '/users/sign_in'
    }
  }
}
