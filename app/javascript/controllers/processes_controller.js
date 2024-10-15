import { Controller } from "@hotwired/stimulus"
import tippy from "tippy.js";


export default class extends Controller {
  static targets = ["command"]

  connect() {
  }

  copyToClick(event) {
    navigator.clipboard.writeText(this.commandTarget.textContent)
    this.tooltip(event.target)
  }

  tooltip(target) {
    tippy(target, {
      content: "Copied!",
      showOnCreate: true,
      onHidden: (instance) => {
        instance.destroy()
      }
    })
  }

  showConnectionInstructions(event) {
    event.preventDefault();
    const text = `KUBECONFIG=/path/to/kubeconfig kubectl exec -it ${event.target.dataset.podName} -- /bin/bash`
    this.commandTarget.textContent = text
    click_outside_modal.showModal()
  }
}