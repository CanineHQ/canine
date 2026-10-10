import { Controller } from "@hotwired/stimulus"

// Types out the part of an element's text after `from` characters, once: for the agent's notes as they arrive
export default class extends Controller {
  static values = { from: Number }

  connect() {
    const text = this.element.textContent
    let shown = Math.min(this.fromValue, text.length)
    this.element.textContent = text.slice(0, shown)
    this.timer = setInterval(() => {
      shown = Math.min(text.length, shown + 3)
      this.element.textContent = text.slice(0, shown)
      if (shown >= text.length) clearInterval(this.timer)
    }, 15)
  }

  disconnect() {
    clearInterval(this.timer)
  }
}
