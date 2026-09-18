import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["placeholder", "editorContainer", "editButton"]

  connect() {
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.remove("hidden")
    }
    if (this.hasEditorContainerTarget) {
      this.editorContainerTarget.classList.add("hidden")
    }
  }

  toggleEdit() {
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.add("hidden")
    }
    if (this.hasEditorContainerTarget) {
      this.editorContainerTarget.classList.remove("hidden")
    }
    if (this.hasEditButtonTarget) {
      this.editButtonTarget.classList.add("hidden")
    }
  }

  cancelEdit() {
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.remove("hidden")
    }
    if (this.hasEditorContainerTarget) {
      this.editorContainerTarget.classList.add("hidden")
    }
    if (this.hasEditButtonTarget) {
      this.editButtonTarget.classList.remove("hidden")
    }
  }
}