import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "input", "slider", "cpu_requestField", "cpu_limitField", "memory_requestField", "memory_limitField"]

  toggleResourceConstraints(event) {
    if (event.target.checked) {
      this.containerTarget.classList.remove("hidden")
    } else {
      this.containerTarget.classList.add("hidden")
    }
  }

  toggleField(event) {
    const fieldName = event.params.field
    const isEnabled = event.target.checked
    const fieldTarget = `${fieldName}FieldTarget`

    if (this[fieldTarget]) {
      const field = this[fieldTarget]
      const numberInput = field.querySelector('input[type="number"]')
      const rangeInput = field.querySelector('input[type="range"]')

      if (isEnabled) {
        // Enable and set default values
        numberInput.removeAttribute('readonly')
        numberInput.classList.remove('opacity-50', 'cursor-not-allowed')
        rangeInput.disabled = false

        if (fieldName.includes('cpu')) {
          numberInput.value = '0.5'
          rangeInput.value = '0.5'
        } else if (fieldName.includes('memory')) {
          numberInput.value = '128'
          rangeInput.value = '128'
        }
      } else {
        // Make readonly and set to empty so form sends nil
        numberInput.setAttribute('readonly', 'readonly')
        numberInput.classList.add('opacity-50', 'cursor-not-allowed')
        rangeInput.disabled = true
        numberInput.value = ''
      }
    }
  }
}
