import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["kubeconfigInput", "submit"]

  connect() {
this.updateSubmitState()
  }

  updateSubmitState() {
    const hasKubeconfig = this.kubeconfigInputTargets.some(input => input.value.trim() !== "")
    this.submitTarget.disabled = !hasKubeconfig
  }
}
