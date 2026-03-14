import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["digit", "hidden"]
  static values = { pattern: { type: String, default: "[0-9]" } }

  connect() {
    this.regex = new RegExp(this.patternValue)
    this.digitTargets[0]?.focus()
    this.element.closest("form")?.addEventListener("submit", this.#guardSubmit)
  }

  disconnect() {
    this.element.closest("form")?.removeEventListener("submit", this.#guardSubmit)
  }

  input(event) {
    const field = event.target
    const index = this.digitTargets.indexOf(field)

    if (field.value.length > 1) field.value = field.value.slice(-1)

    if (!this.regex.test(field.value)) {
      field.value = ""
      return
    }

    if (field.value && index < this.digitTargets.length - 1) {
      this.digitTargets[index + 1].focus()
    } else if (field.value && index === this.digitTargets.length - 1) {
      document.activeElement?.blur()
    }

    this.#updateHiddenField()
  }

  keydown(event) {
    const field = event.target
    const index = this.digitTargets.indexOf(field)

    if (event.key === "Backspace" && !field.value && index > 0) {
      this.digitTargets[index - 1].focus()
      this.digitTargets[index - 1].value = ""
      this.#updateHiddenField()
    } else if (event.key === "ArrowLeft" && index > 0) {
      this.digitTargets[index - 1].focus()
    } else if (event.key === "ArrowRight" && index < this.digitTargets.length - 1) {
      this.digitTargets[index + 1].focus()
    }
  }

  async paste(event) {
    event.preventDefault()
    try {
      const text = await navigator.clipboard.readText()
      const filtered = this.#filter(text)
      filtered.split("").forEach((char, i) => {
        if (this.digitTargets[i]) this.digitTargets[i].value = char
      })
      if (filtered.length >= this.digitTargets.length) {
        document.activeElement?.blur()
      } else {
        this.digitTargets[filtered.length]?.focus()
      }
      this.#updateHiddenField()
    } catch {
      // Clipboard API unavailable — fall through to native paste
    }
  }

  #filter(text) {
    return text.split("").filter(c => this.regex.test(c)).slice(0, this.digitTargets.length).join("")
  }

  #updateHiddenField() {
    this.hiddenTarget.value = this.digitTargets.map(d => d.value).join("")
    this.#updateBoxStyles()
  }

  #updateBoxStyles() {
    this.digitTargets.forEach(d => {
      d.classList.toggle("border-primary", !!d.value)
      d.classList.toggle("border-base-300", !d.value)
    })
  }

  #guardSubmit = (event) => {
    if (this.hiddenTarget.value.length < this.digitTargets.length) {
      event.preventDefault()
      this.digitTargets.find(d => !d.value)?.focus()
    }
  }
}
