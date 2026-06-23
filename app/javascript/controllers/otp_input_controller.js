import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["digit", "hidden"]

  connect() {
    this.digitTargets[0]?.focus()
  }

  input(event) {
    const input = event.target
    const value = input.value

    if (value.length > 1) {
      // Handle paste
      const digits = value.replace(/\D/g, "").slice(0, 6).split("")
      this.digitTargets.forEach((el, i) => {
        el.value = digits[i] || ""
      })
      const nextIndex = Math.min(digits.length, 5)
      this.digitTargets[nextIndex]?.focus()
    } else if (value.length === 1) {
      const index = this.digitTargets.indexOf(input)
      if (index < 5) this.digitTargets[index + 1]?.focus()
    }

    this.updateHidden()
  }

  keydown(event) {
    const input = event.target
    const index = this.digitTargets.indexOf(input)

    if (event.key === "Backspace" && input.value === "" && index > 0) {
      this.digitTargets[index - 1].value = ""
      this.digitTargets[index - 1].focus()
      this.updateHidden()
    }
  }

  paste(event) {
    event.preventDefault()
    const text = (event.clipboardData || window.clipboardData).getData("text")
    const digits = text.replace(/\D/g, "").slice(0, 6).split("")
    this.digitTargets.forEach((el, i) => {
      el.value = digits[i] || ""
    })
    const nextIndex = Math.min(digits.length, 5)
    this.digitTargets[nextIndex]?.focus()
    this.updateHidden()
  }

  updateHidden() {
    this.hiddenTarget.value = this.digitTargets.map(el => el.value).join("")
  }
}
