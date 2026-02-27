import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["placeholder", "editorContainer", "editButton"]

  connect() {
    // Ensure initial state is correct
    if (this.hasPlaceholderTarget) this.placeholderTarget.classList.remove("hidden")
    if (this.hasEditorContainerTarget) this.editorContainerTarget.classList.add("hidden")
  }

  toggleEdit() {
    const isHidden = this.hasEditorContainerTarget && this.editorContainerTarget.classList.contains("hidden")
    if (isHidden) {
      if (this.hasPlaceholderTarget) this.placeholderTarget.classList.add("hidden")
      if (this.hasEditorContainerTarget) this.editorContainerTarget.classList.remove("hidden")
      if (this.hasEditButtonTarget) this.editButtonTarget.classList.add("hidden")
    } else {
      this.cancelEdit()
    }
  }

  cancelEdit() {
    if (this.hasPlaceholderTarget) this.placeholderTarget.classList.remove("hidden")
    if (this.hasEditorContainerTarget) this.editorContainerTarget.classList.add("hidden")
    if (this.hasEditButtonTarget) this.editButtonTarget.classList.remove("hidden")
  }
}