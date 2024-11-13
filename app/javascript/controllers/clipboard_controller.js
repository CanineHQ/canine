import { Controller } from "@hotwired/stimulus"
import ClipboardJS from "clipboard"
import tippy from "tippy.js";

export default class extends Controller {
  static values = {
    successMessage: String,
    errorMessage: String
  }

  connect() {
    this.clipboard = new ClipboardJS(this.element)
    this.clipboard.on("success", (e) => this.tooltip(this.successMessage))
    this.clipboard.on("error",   (e) => this.tooltip(this.errorMessage))
  }

  tooltip(message) {
    tippy(this.element, {
      theme: "light",
      content: message,
      showOnCreate: true,
      onHidden: (instance) => {
        instance.destroy()
      }
    })
  }

  get successMessage() {
    return this.successMessageValue || "Copied!"
  }

  get errorMessage() {
    return this.errorMessageValue || "Failed!"
  }
}