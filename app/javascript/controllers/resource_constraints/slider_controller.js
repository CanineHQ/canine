import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slider", "numberInput"]
  static values = {
    type: String
  }

  updateValue(event) {
    if (this.hasNumberInputTarget) {
      if (this.typeValue === "float") {
        this.numberInputTarget.value = parseFloat(event.target.value).toFixed(1)
      } else {
        this.numberInputTarget.value = parseInt(event.target.value)
      }
    }
  }

  updateSlider(event) {
    if (this.hasSliderTarget) {
      if (this.typeValue === "float") {
        const value = parseFloat(event.target.value)
        this.sliderTarget.value = value
      } else {
        const value = parseInt(event.target.value)
        this.sliderTarget.value = value
      }
    }
  }
}

