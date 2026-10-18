import { Controller } from "@hotwired/stimulus"

// A computer's Selkies desktop, full window in an iframe. Selkies lets one tab control a desktop at a time: when another
// tab connects as the controller, this one's stream is closed ("Connection Terminated"), and we offer to take it back
// or keep watching. Watch mode joins as a view-only viewer (Selkies' #shared link), which never displaces anyone.
// The person and the agents share the computer: runs work on workspaces of their own, so nothing pauses while it's open.

export default class extends Controller {
  static targets = ["frame", "status", "statusText", "replaced"]
  static values = { url: String, watch: Boolean }

  connect() {
    this.load()
    this.healthCheck = setInterval(() => this.checkHealth(), 5000)
    this.replacedCheck = setInterval(() => this.checkReplaced(), 1000)
    // Release only a lock WE took (see fullscreen()), and only on exit — never Selkies' own lock from its fullscreen.
    this.onFullscreenChange = () => {
      if (!document.fullscreenElement && this.locked) {
        navigator.keyboard?.unlock?.()
        this.locked = false
      }
    }
    document.addEventListener("fullscreenchange", this.onFullscreenChange)
  }

  disconnect() {
    clearInterval(this.healthCheck)
    clearInterval(this.replacedCheck)
    document.removeEventListener("fullscreenchange", this.onFullscreenChange)
    if (this.locked) navigator.keyboard?.unlock?.()
  }

  // Go fullscreen on the stream and capture the keys the browser/OS would otherwise intercept, so Cmd (which maps to
  // Super) can reach Omarchy shortcuts like the launcher. Keyboard Lock only works from the top-level page, so the
  // parent takes it here and focuses the frame so the captured keys go to the desktop. macOS still reserves a few
  // combos it won't release (Cmd+Space, Cmd+Tab) — hence the SUPER+D/SUPER+N bindings on the computer itself.
  fullscreen() {
    this.frameTarget.requestFullscreen().then(() => {
      this.frameTarget.contentWindow?.focus()
      navigator.keyboard?.lock?.().then(() => { this.locked = true }).catch(() => {})
    }).catch(() => {})
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
