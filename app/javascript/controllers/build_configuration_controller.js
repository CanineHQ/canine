import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["driver", "clusterSelect", "clusterInput"]

  connect() {
    this.toggleClusterSelect()
  }

  toggleClusterSelect() {
    const driver = this.driverTarget.value
    
    if (driver === 'k8s') {
      this.clusterSelectTarget.classList.remove('hidden')
      if (this.hasClusterInputTarget) {
        this.clusterInputTarget.required = true
      }
    } else {
      this.clusterSelectTarget.classList.add('hidden')
      if (this.hasClusterInputTarget) {
        this.clusterInputTarget.required = false
        this.clusterInputTarget.value = ""
      }
    }
  }
}