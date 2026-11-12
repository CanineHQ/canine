import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["radio", "partial"]

  connect() {
    this.toggle()
  }

  toggle() {
    const selectedRadio = this.radioTargets.find(radio => radio.checked)

    if (selectedRadio) {
      const selectedValue = selectedRadio.value

      this.partialTargets.forEach(partial => {
        const hidden = partial.dataset.value !== selectedValue
        partial.classList.toggle('hidden', hidden)
        // Hidden partials can share field names (e.g. webhook_url); disable them so they aren't submitted
        partial.querySelectorAll('input, select, textarea').forEach(field => { field.disabled = hidden })
      })
    }
  }
}
