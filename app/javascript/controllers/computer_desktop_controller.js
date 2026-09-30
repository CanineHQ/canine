import { Controller } from "@hotwired/stimulus"

// A computer's Selkies desktop, full window in an iframe. Selkies lets one tab control a desktop at a time: when another
// tab connects as the controller, this one's stream is closed ("Connection Terminated"), and we offer to take it back
// or keep watching. Watch mode joins as a view-only viewer (Selkies' #shared link), which never displaces anyone.
export default class extends Controller {
  static targets = ["frame", "status", "statusText", "replaced"]
  static values = { url: String, watch: Boolean }

  connect() {
    this.load()
    this.healthCheck = setInterval(() => this.checkHealth(), 5000)
    this.replacedCheck = setInterval(() => this.checkReplaced(), 1000)
  }

  disconnect() {
    clearInterval(this.healthCheck)
    clearInterval(this.replacedCheck)
  }

  // A fresh query string forces a real reload, since changing only the #hash wouldn't
  load() {
    this.replacedTarget.classList.add("hidden")
    this.frameTarget.onload = () => this.statusTarget.classList.add("hidden")
    this.frameTarget.src = `${this.urlValue}?load=${Date.now()}${this.watchValue ? "#shared" : ""}`
  }

  reconnect() {
    this.showStatus("Reconnecting...")
    this.load()
  }

  takeOver() {
    this.load()
  }

  // The proxy answering again after an outage means the desktop is back
  checkHealth() {
    fetch(this.urlValue, { method: "HEAD", mode: "no-cors" })
      .then(() => {
        if (this.wasDown) {
          this.wasDown = false
          this.reconnect()
        }
      })
      .catch(() => {
        this.wasDown = true
        this.showStatus("Connection lost — waiting to reconnect...")
      })
  }

  // The iframe is served through Canine's proxy, so it's same-origin and we can read the notice Selkies shows
  checkReplaced() {
    if (this.watchValue || !this.replacedTarget.classList.contains("hidden")) return
    try {
      const text = this.frameTarget.contentDocument?.body?.textContent || ""
      if (text.includes("Connection Terminated")) this.replacedTarget.classList.remove("hidden")
    } catch {
      // Not loaded yet
    }
  }

  showStatus(text) {
    this.statusTextTarget.textContent = text
    this.statusTarget.classList.remove("hidden")
  }
}
