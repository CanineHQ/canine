import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["urlInput", "buttons"]
  
  static values = {
    registries: Object
  }
  
  connect() {
    this.registriesValue = {
      dockerhub: "docker.io",
      ghcr: "ghcr.io",
      gcr: "gcr.io",
      ecr: "ecr.amazonaws.com",
      acr: "azurecr.io"
    }
    
    // Disable URL field by default
    this.urlInputTarget.classList.add('bg-base-200')
  }
  
  selectRegistry(event) {
    const registry = event.currentTarget.dataset.registry
    
    if (registry === "other") {
      this.urlInputTarget.value = ""
      this.urlInputTarget.readOnly = false
      this.urlInputTarget.classList.remove('bg-base-200')
      this.urlInputTarget.focus()
    } else if (this.registriesValue[registry]) {
      this.urlInputTarget.value = this.registriesValue[registry]
      this.urlInputTarget.readOnly = true
      this.urlInputTarget.classList.add('bg-base-200')
    }
    
    // Update active button state
    this.element.querySelectorAll('[data-action="click->registry-selector#selectRegistry"]').forEach(btn => {
      btn.classList.remove('btn-active', 'btn-primary')
      btn.classList.add('btn-outline')
    })
    event.currentTarget.classList.remove('btn-outline')
    event.currentTarget.classList.add('btn-active', 'btn-primary')
  }
}