import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["command"]

  connect() {
  }

  copyToClick(event) {
    navigator.clipboard.writeText(this.commandTarget.textContent)
    const element = event.currentTarget
    element.classList.add('animate-click')
    setTimeout(() => element.classList.remove('animate-click'), 300)
  }

  showConnectionInstructions(event) {
    event.preventDefault();
    const text = `KUBECONFIG=/path/to/kubeconfig kubectl exec -it -n ${event.target.dataset.namespace} ${event.target.dataset.podName} -- /bin/bash`
    this.commandTarget.textContent = text
    click_outside_modal.showModal()
  }
}