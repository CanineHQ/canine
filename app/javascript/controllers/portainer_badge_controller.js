import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon", "link"]
  static values = { url: String }

  connect() {
    console.log('connect', this.urlValue)
    this.verifyUrl()
  }

  async verifyUrl() {
    if (!this.urlValue) return

    this.showLoading()

    try {
      const response = await fetch(`/stack_manager/verify_url?url=${encodeURIComponent(this.urlValue)}`, {
        method: 'GET',
      })

      const data = await response.json()

      if (data.success) {
        this.showSuccess()
      } else {
        this.showError()
      }
    } catch (error) {
      this.showError()
    }
  }

  showLoading() {
    this.iconTarget.setAttribute('icon', 'lucide:loader-2')
    this.iconTarget.classList.add('animate-spin')
    this.linkTarget.classList.add('opacity-50')
  }

  showSuccess() {
    this.iconTarget.setAttribute('icon', 'lucide:external-link')
    this.iconTarget.classList.remove('animate-spin')
    this.linkTarget.classList.remove('opacity-50')
  }

  showError() {
    this.iconTarget.setAttribute('icon', 'lucide:alert-circle')
    this.iconTarget.classList.remove('animate-spin')
    this.linkTarget.classList.add('opacity-50')
    this.linkTarget.style.pointerEvents = 'none'
  }
}
