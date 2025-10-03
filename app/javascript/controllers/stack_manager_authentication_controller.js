import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  connect() {
    this.checkAuthentication()
  }

  async checkAuthentication() {
    try {
      const response = await fetch('/stack_manager/authenticated', {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
        },
        credentials: 'same-origin'
      })

      if (!response.ok) {
        await this.logout()
      }
    } catch (error) {
      console.error('Authentication check failed:', error)
      await this.logout()
    }
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
        Turbo.visit('/users/sign_in', { action: 'replace' })
      }
    } catch (error) {
      console.error('Logout failed:', error)
      window.location.href = '/users/sign_in'
    }
  }
}