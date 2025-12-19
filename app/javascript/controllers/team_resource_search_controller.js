import AsyncSearchDropdownController from "./components/async_search_dropdown_controller"

export default class extends AsyncSearchDropdownController {
  static values = {
    url: String,
    addUrl: String,
    resourceType: String,
    turboFrame: String
  }

  async fetchResults(query) {
    const url = `${this.urlValue}.json?q=${encodeURIComponent(query)}`
    const response = await fetch(url, {
      headers: {
        'Accept': 'application/json'
      }
    })

    if (!response.ok) {
      throw new Error('Failed to search resources')
    }

    return await response.json()
  }

  renderItem(resource) {
    return `
      <div class="flex items-center gap-3 px-2 py-2">
        <div class="flex-1 min-w-0">
          <div class="font-medium truncate">${this.escapeHtml(resource.name)}</div>
        </div>
      </div>
    `
  }

  async onItemSelect(resource, itemElement) {
    try {
      itemElement.classList.add('opacity-50')
      itemElement.innerHTML = `
        <div class="flex items-center gap-2">
          <span class="loading loading-spinner loading-sm"></span>
          <span>Adding ${this.escapeHtml(resource.name)}...</span>
        </div>
      `

      const response = await fetch(this.addUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCsrfToken()
        },
        body: JSON.stringify({
          resourceable_type: this.resourceTypeValue,
          resourceable_id: resource.id
        })
      })

      if (!response.ok) {
        throw new Error('Failed to add resource')
      }

      // Close the modal
      const modal = this.element.closest('dialog')
      if (modal) {
        modal.close()
      }

      // Reload the turbo frame
      if (this.hasTurboFrameValue) {
        const frame = document.getElementById(this.turboFrameValue)
        if (frame) {
          frame.reload()
        }
      } else {
        window.location.reload()
      }
    } catch (error) {
      console.error('Error adding resource:', error)
      alert('Failed to add resource. Please try again.')
      itemElement.classList.remove('opacity-50')
    }
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  getCsrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ''
  }
}
