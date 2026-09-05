import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Watch for turbo stream updates to doctor checks — when content changes, open the modal
    this.observer = new MutationObserver(() => {
      this.element.showModal()
    })

    const checksContainer = document.getElementById("doctor-checks")
    if (checksContainer) {
      this.observer.observe(checksContainer, { childList: true, subtree: true, characterData: true })
    }
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
