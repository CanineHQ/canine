import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "trigger", "dropdown", "option", "list"]

  connect() {
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
  }

  toggle() {
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.dropdownTarget.classList.remove("hidden")
    document.addEventListener("click", this.closeOnOutsideClick)

    const selected = this.optionTargets.find(
      opt => opt.dataset.value === this.inputTarget.value
    ) || this.enabledOptions[0]

    if (selected) selected.focus()
  }

  close() {
    this.dropdownTarget.classList.add("hidden")
    document.removeEventListener("click", this.closeOnOutsideClick)
  }

  get isOpen() {
    return !this.dropdownTarget.classList.contains("hidden")
  }

  get enabledOptions() {
    return this.optionTargets.filter(opt => !("disabled" in opt.dataset))
  }

  select(event) {
    const option = event.currentTarget
    if ("disabled" in option.dataset) return

    const value = option.dataset.value

    this.inputTarget.value = value
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))

    this.triggerTarget.innerHTML = option.innerHTML

    this.optionTargets.forEach(opt => {
      opt.classList.toggle("bg-base-200", opt.dataset.value === value)
    })

    this.close()
    this.triggerTarget.focus()
  }

  onTriggerKeydown(event) {
    switch (event.key) {
      case "ArrowDown":
      case "ArrowUp":
      case "Enter":
      case " ":
        event.preventDefault()
        if (!this.isOpen) this.open()
        break
      case "Escape":
        event.preventDefault()
        this.close()
        break
    }
  }

  onOptionKeydown(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.focusNextOption(event.currentTarget)
        break
      case "ArrowUp":
        event.preventDefault()
        this.focusPreviousOption(event.currentTarget)
        break
      case "Enter":
      case " ":
        event.preventDefault()
        this.select(event)
        break
      case "Escape":
        event.preventDefault()
        this.close()
        this.triggerTarget.focus()
        break
    }
  }

  focusNextOption(current) {
    const enabled = this.enabledOptions
    const index = enabled.indexOf(current)
    const next = enabled[index + 1] || enabled[0]
    if (next) next.focus()
  }

  focusPreviousOption(current) {
    const enabled = this.enabledOptions
    const index = enabled.indexOf(current)
    const prev = enabled[index - 1] || enabled[enabled.length - 1]
    if (prev) prev.focus()
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
}
