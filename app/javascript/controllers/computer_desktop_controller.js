import { Controller } from "@hotwired/stimulus"

// A computer's Selkies desktop, full window in an iframe. Selkies lets one tab control a desktop at a time: when another
// tab connects as the controller, this one's stream is closed ("Connection Terminated"), and we offer to take it back
// or keep watching. Watch mode joins as a view-only viewer (Selkies' #shared link), which never displaces anyone.
//
// While the person uses the desktop, agents are paused from it: this page reports their activity to the computer-use
// server (at most every few seconds), which pauses the agent until they've been idle a while (human.py in the VM).
const ACTIVITY_EVENTS = ["keydown", "pointerdown", "pointermove", "wheel"]
const REPORT_EVERY_MS = 3000
const IDLE_MS = 20000 // matches human.IDLE_SECONDS

export default class extends Controller {
  static targets = ["frame", "status", "statusText", "replaced", "human", "humanText", "takeOverButton"]
  static values = { url: String, watch: Boolean, humanUrl: String }

  connect() {
    this.load()
    this.healthCheck = setInterval(() => this.checkHealth(), 5000)
    this.replacedCheck = setInterval(() => this.checkReplaced(), 1000)
    if (!this.watchValue) {
      this.onActivity = (event) => this.reportActivity(event)
      this.listenForActivity(window)
    }
  }

  disconnect() {
    clearInterval(this.healthCheck)
    clearInterval(this.replacedCheck)
    clearTimeout(this.idleTimer)
    ACTIVITY_EVENTS.forEach((type) => window.removeEventListener(type, this.onActivity, true))
  }

  // A fresh query string forces a real reload, since changing only the #hash wouldn't
  load() {
    this.replacedTarget.classList.add("hidden")
    this.frameTarget.onload = () => {
      this.statusTarget.classList.add("hidden")
      // The stream is served through Canine's proxy, so it's same-origin and we can hear input inside it
      if (this.onActivity) this.listenForActivity(this.frameTarget.contentWindow)
    }
    this.frameTarget.src = `${this.urlValue}?load=${Date.now()}${this.watchValue ? "#shared" : ""}`
  }

  listenForActivity(target) {
    ACTIVITY_EVENTS.forEach((type) => target.addEventListener(type, this.onActivity, { capture: true, passive: true }))
  }

  reportActivity(event) {
    if (this.hasHumanTarget && this.humanTarget.contains(event.target)) return // clicking "Hand back" isn't using it
    if (!this.lastReport || Date.now() - this.lastReport > REPORT_EVERY_MS) {
      this.lastReport = Date.now()
      this.postHuman("activity")
    }
    this.showHuman("You're using this computer, so agents are paused.")
    clearTimeout(this.idleTimer)
    if (!this.takenOver) this.idleTimer = setTimeout(() => this.hideHuman(), IDLE_MS)
  }

  takeOver() {
    this.takenOver = true
    clearTimeout(this.idleTimer)
    this.postHuman("take_over")
    this.showHuman("You've taken over: agents are paused until you hand back.")
  }

  handBack() {
    this.takenOver = false
    clearTimeout(this.idleTimer)
    this.postHuman("hand_back")
    this.hideHuman()
  }

  postHuman(what) {
    fetch(`${this.humanUrlValue}${what}`, { method: "POST", keepalive: true }).catch(() => {})
  }

  showHuman(text) {
    this.humanTextTarget.textContent = text
    this.takeOverButtonTarget.classList.toggle("hidden", !!this.takenOver)
    this.humanTarget.classList.remove("hidden")
  }

  hideHuman() {
    this.humanTarget.classList.add("hidden")
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
