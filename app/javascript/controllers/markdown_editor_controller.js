import { default as MarkdownIt } from "markdown-it"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["markdownTextarea", "previewContainer", "toggleButton"]

  connect() {
    // Sync the preview container with the markdown container
    this.updatePreview()
    this.toggleButtonTarget.innerHTML = "Edit"
  }

  updatePreview() {
    const markdown = this.markdownTextareaTarget.value
    const html = MarkdownIt().render(markdown)
    if (html.length) {
      this.previewContainerTarget.innerHTML = html
    } else {
      this.previewContainerTarget.innerHTML = "<i class='text-gray-500'>Nothing here yet</i>"
    }
  }

  // Add this method to handle input events
  preview() {
    this.updatePreview()
  }

  toggle(event) {
    event.preventDefault()
    this.markdownTextareaTarget.classList.toggle("hidden")
    this.previewContainerTarget.classList.toggle("hidden")
    this.toggleButtonTarget.innerHTML = this.toggleButtonTarget.innerHTML === "Edit" ? "Preview" : "Edit"
    this.markdownTextareaTarget.focus()
  }
}
