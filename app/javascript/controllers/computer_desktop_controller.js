import { Controller } from "@hotwired/stimulus"

// A computer's Selkies desktop, full window in an iframe. Selkies lets one tab control a desktop at a time: when another
// tab connects as the controller, this one's stream is closed ("Connection Terminated"), and we offer to take it back
// or keep watching. Watch mode joins as a view-only viewer (Selkies' #shared link), which never displaces anyone.
//
// While a person has the controlling tab open, the agent is locked out of the screen. We hold that lock on the
// computer-use server (human.py in the VM) with a heartbeat for as long as this tab is open and visible — so the agent
// stays paused even while the person is only reading the screen, not touching anything. (Reporting activity only on
// input let the lock decay after ~20s, so the agent would grab the mouse the moment they paused.) The heartbeat's short
// server-side TTL means the computer frees itself if this tab goes away. "Hand back" releases the lock to let the agent
// drive while the person watches; any input, or "Take over", re-takes it.
const ACTIVITY_EVENTS = ["keydown", "pointerdown", "pointermove", "wheel"]
const HEARTBEAT_MS = 5000 // must stay well under human.IDLE_SECONDS so one missed beat doesn't drop the lock

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
      this.onVisibility = () => this.syncPresence()
      document.addEventListener("visibilitychange", this.onVisibility)
      this.syncPresence()
    }
  }

  disconnect() {
    clearInterval(this.healthCheck)
    clearInterval(this.replacedCheck)
    this.stopHeartbeat()
    if (this.onVisibility) document.removeEventListener("visibilitychange", this.onVisibility)
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

  // Hold the lock whenever this controlling tab is in the foreground (unless the person handed it back on purpose).
  // Leaving the tab stops the heartbeat and the server's TTL frees the computer for the agent.
  syncPresence() {
    if (document.visibilityState === "visible" && !this.released) this.startHeartbeat()
    else this.stopHeartbeat()
  }

  startHeartbeat() {
    if (this.heartbeat) return
    this.beat()
    this.heartbeat = setInterval(() => this.beat(), HEARTBEAT_MS)
    // A scheduled run always pauses while you're here; a run you started yourself keeps going (Take over pauses it too).
    this.showHuman(this.takenOver ? "You've taken over: agents are paused until you hand back." : "You're using this computer — scheduled runs are paused. Take over to pause everything.")
  }

  stopHeartbeat() {
    clearInterval(this.heartbeat)
    this.heartbeat = null
    if (!this.takenOver) this.hideHuman()
  }

  beat() {
    this.postHuman(this.takenOver ? "take_over" : "activity")
  }

  // Touching the desktop after handing back means they're driving again: take the lock back.
  reportActivity(event) {
    if (this.hasHumanTarget && this.humanTarget.contains(event.target)) return // clicking "Hand back" isn't using it
    if (this.released) {
      this.released = false
      this.syncPresence()
    }
  }

  // Keep the lock even after stepping away: take_over holds until hand_back, regardless of the heartbeat or idleness.
  takeOver() {
    this.takenOver = true
    this.released = false
    this.startHeartbeat()
  }

  handBack() {
    this.takenOver = false
    this.released = true
    this.stopHeartbeat()
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
