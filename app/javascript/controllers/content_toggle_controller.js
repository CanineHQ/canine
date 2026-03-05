import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["placeholder", "editorContainer", "editButton"]

  connect() {
    // Ensure initial state is correct
    this.placeholderTarget.classList.remove("hidden")
    this.editorContainerTarget.classList.add("hidden")
  }

  toggleEdit() {
    this.placeholderTarget.classList.add("hidden")
    this.editorContainerTarget.classList.remove("hidden")
    this.editButtonTarget.classList.add("hidden")
  }

  cancelEdit() {
    this.placeholderTarget.classList.remove("hidden")
    this.editorContainerTarget.classList.add("hidden")
    this.editButtonTarget.classList.remove("hidden")
  }
}