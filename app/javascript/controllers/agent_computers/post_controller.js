import { Controller } from "@hotwired/stimulus"

// A feed post's action bar, like a social feed's: hovering the tag button (or holding it, on a phone) pops up the tag
// picker, and Comment opens the comment box. In the box, Enter sends and Shift+Enter is a new line.
export default class extends Controller {
  static targets = ["picker", "composer"]

  disconnect() {
    clearTimeout(this.pickerTimer)
    clearTimeout(this.holdTimer)
  }

  showPicker() {
    clearTimeout(this.pickerTimer)
    this.pickerTimer = setTimeout(() => this.togglePicker(true), 400)
  }

  hidePicker() {
    clearTimeout(this.pickerTimer)
    this.pickerTimer = setTimeout(() => this.togglePicker(false), 300)
  }

  togglePicker(open) {
    if (!this.hasPickerTarget) return
    this.pickerTarget.classList.toggle("hidden", !open)
    this.pickerTarget.classList.toggle("flex", open)
  }

  // A long press opens the picker instead of tagging
  holdStart() {
    this.held = false
    this.holdTimer = setTimeout(() => {
      this.held = true
      this.togglePicker(true)
    }, 450)
  }

  holdEnd(event) {
    clearTimeout(this.holdTimer)
    if (this.held) event.preventDefault()
  }

  comment() {
    this.composerTarget.classList.remove("hidden")
    const textarea = this.composerTarget.querySelector("textarea")
    if (!textarea) return
    // textarea-autogrow sized it while it was hidden, when it measures 0px tall; have it measure again now it shows
    textarea.dispatchEvent(new Event("input"))
    textarea.focus()
  }

  send(event) {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return
    event.preventDefault()
    if (event.target.value.trim()) event.target.form.requestSubmit()
  }
}
