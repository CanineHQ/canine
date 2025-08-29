import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "stepHeader", "portainerUrlForm", "githubForm", "step"]
  static values = {
    currentStep: Number
  }


  connect() {
    this.currentStepValue = 0 
    this.activeClass = "step-primary"
  }

  disconnect() {
  }

  next() {
    if (this.currentStepValue == 1) {
      this.submit(this.portainerUrlFormTarget)
    }
    if (this.currentStepValue == 2) {
      this.submit(this.githubFormTarget)
    }
    if (this.currentStepValue < 2) {
      this.currentStepValue++
      this.stepHeaderTargets.forEach(step => step.classList.remove(this.activeClass))
      this.stepHeaderTargets[this.currentStepValue].classList.add(this.activeClass)
      this.stepTargets.forEach(step => step.classList.add("hidden"))
      this.stepTargets[this.currentStepValue].classList.remove("hidden")
    }
  }

  submit(target) {
    const formData = new FormData(target)
    
    fetch(target.action, {
      method: 'PUT',
      body: formData,
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      }
    })
    .then(response => response.json())
    .then(data => {
      // Handle success - maybe show next step or success message
      console.log('Success:', data)
    })
    .catch(error => {
      console.error('Error:', error)
    })
  }

}
