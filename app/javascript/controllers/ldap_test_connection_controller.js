import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "result"]

  async test(event) {
    debugger
    event.preventDefault()

    const form = this.element.closest("form")
    const formData = new FormData(form)

    // Clear previous result
    this.resultTarget.innerHTML = ""

    // Update button to show loading state
    const button = this.buttonTarget
    const originalContent = button.innerHTML
    button.disabled = true
    button.innerHTML = '<span class="loading loading-spinner loading-xs"></span> Testing...'

    try {
      const response = await fetch("/accounts/sso_provider/test_connection", {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: formData
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    } catch (error) {
      console.error("LDAP test connection failed:", error)
    } finally {
      // Always re-enable the button so it can be clicked again
      button.disabled = false
      button.innerHTML = originalContent
    }
  }
}
