import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["radio", "partial"]
  
  connect() {
    this.toggle()
  }

  toggle() {
    const selectedRadio = this.radioTargets.find(radio => radio.checked)
    console.log(selectedRadio)
    
    if (selectedRadio) {
      const selectedValue = selectedRadio.value
      
      this.partialTargets.forEach(partial => {
        if (partial.dataset.value === selectedValue) {
          console.log(partial)
          partial.classList.remove('hidden')
        } else {
          partial.classList.add('hidden')
        }
      })
    }
  }
}
