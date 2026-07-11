import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "status"]
  static values = { url: String }

  connect() {
    this.timeout = null
  }

  validate() {
    clearTimeout(this.timeout)
    const value = this.inputTarget.value.trim()

    if (!value) {
      this.statusTarget.innerHTML = ""
      return
    }

    this.timeout = setTimeout(() => this.checkImage(value), 500)
  }

  async checkImage(imageUrl) {
    this.statusTarget.innerHTML = `
      <span class="flex items-center gap-1.5 text-sm text-base-content/50">
        <span class="loading loading-spinner loading-xs"></span>
        Checking image...
      </span>
    `

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
        },
        body: JSON.stringify({ image_url: imageUrl }),
      })
      const data = await response.json()

      if (data.valid) {
        this.statusTarget.innerHTML = `
          <span class="flex items-center gap-1.5 text-sm text-success">
            <iconify-icon icon="lucide:check-circle" width="16"></iconify-icon>
            Image found
          </span>
        `
      } else {
        this.statusTarget.innerHTML = `
          <span class="flex items-center gap-1.5 text-sm text-error">
            <iconify-icon icon="lucide:x-circle" width="16"></iconify-icon>
            ${this.escapeHtml(data.error)}
          </span>
        `
      }
    } catch {
      this.statusTarget.innerHTML = `
        <span class="flex items-center gap-1.5 text-sm text-warning">
          <iconify-icon icon="lucide:alert-triangle" width="16"></iconify-icon>
          Could not validate image
        </span>
      `
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
