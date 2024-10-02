import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "toggleable"]
  static values = {
    selectAttribute: String
  }

  connect() {
    this.toggle()
  }

  toggle() {
    const selectedValue = this.selectTarget.value
    this.toggleableTargets.forEach(element => {
      const shouldShow = element.getAttribute(this.selectTarget.dataset.selectAttributeValue) === selectedValue
      element.classList.toggle('hidden', !shouldShow)
    })
  }
}
