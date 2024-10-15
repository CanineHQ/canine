import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  connect() {
    console.log("processes controller connected")
  }

  showConnectionInstructions(event) {
    event.preventDefault()
    click_outside_modal.showModal()
  }
}