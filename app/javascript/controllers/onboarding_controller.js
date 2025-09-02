import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "stepHeader", "portainerUrlForm", "githubForm", "step", "selectedConfigurationOption", "stepHeaderParent" ]
  static values = {
    currentStep: Number,
    selectedConfigurationOption: String
  }


  connect() {
    this.currentStepValue = 0 
    this.selectedConfigurationOptionValue = 'local'
  }

  disconnect() {
  }

  selectConfigurationOption(event) {
    event.preventDefault()
    this.selectedConfigurationOptionValue = event.currentTarget.dataset.value
    this.selectedConfigurationOptionTargets.forEach(option => option.classList.remove('border-green-500'))
    this.selectedConfigurationOptionTargets.forEach(option => option.querySelector('.checkIcon').classList.add('hidden'))
    event.currentTarget.classList.add('border-green-500')
    event.currentTarget.querySelector('.checkIcon').classList.remove('hidden')
  }

  next() {
    if (this.selectedConfigurationOptionValue == 'local') {
      window.location.href = "/"
      return
    } else {
      this.stepHeaderParentTarget.classList.remove('hidden')
    }
    if (this.currentStepValue == 1) {
      this.submit(this.portainerUrlFormTarget)
    }
    if (this.currentStepValue == 2) {
      this.submit(this.githubFormTarget)
    }
    if (this.currentStepValue < 2) {
      this.currentStepValue++
      this.stepHeaderTargets[this.currentStepValue].classList.add("step-primary")
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
