import AsyncSearchDropdownController from "./components/async_search_dropdown_controller"

export default class extends AsyncSearchDropdownController {
  static values = {
    teamId: String,
    addUrl: String
  }

  async fetchResults(query) {
    const url = `/accounts/teams/${this.teamIdValue}/team_members_search?q=${encodeURIComponent(query)}`
    const response = await fetch(url, {
      headers: {
        'Accept': 'application/json'
      }
    })

    if (!response.ok) {
      throw new Error('Failed to search team members')
    }

    return await response.json()
  }

  renderItem(user) {
    const displayName = user.name || user.first_name || user.email.split('@')[0]
    const showEmail = user.name || user.first_name

    return `
      <div class="flex items-center gap-3 px-2 py-2">
        <div class="avatar">
          <div class="w-8 h-8 rounded">
            <img src="${this.escapeHtml(user.avatar_url)}" alt="${this.escapeHtml(displayName)}" />
          </div>
        </div>
        <div class="flex-1 min-w-0">
          <div class="font-medium truncate">${this.escapeHtml(displayName)}</div>
          ${showEmail ? `<div class="text-sm text-base-content/60 truncate">${this.escapeHtml(user.email)}</div>` : ''}
        </div>
      </div>
    `
  }

  async onItemSelect(user, itemElement) {
    try {
      // Add loading state
      itemElement.classList.add('opacity-50')
      itemElement.innerHTML = `
        <div class="flex items-center gap-2">
          <span class="loading loading-spinner loading-sm"></span>
          <span>Adding ${this.escapeHtml(user.name || user.email)}...</span>
        </div>
      `

      // Send POST request to add team member
      const response = await fetch(this.addUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCsrfToken()
        },
        body: JSON.stringify({ user_id: user.id })
      })

      if (!response.ok) {
        throw new Error('Failed to add team member')
      }

      // Redirect to reload page (or you could use Turbo Stream)
      window.location.reload()
    } catch (error) {
      console.error('Error adding team member:', error)
      alert('Failed to add team member. Please try again.')
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
