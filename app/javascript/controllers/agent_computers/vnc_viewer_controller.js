import { Controller } from "@hotwired/stimulus"
import RFB from "@novnc/novnc/core/rfb"

// Shows a VM's own screen through Canine's relay to KubeVirt's VNC endpoint (/agent_computers/:id/vnc)
export default class extends Controller {
  static targets = ["screen", "status"]
  static values = { url: String }

  connect() {
    this.open()
  }

  disconnect() {
    this.closing = true
    clearTimeout(this.retry)
    this.rfb?.disconnect()
  }

  open() {
    const scheme = window.location.protocol === "https:" ? "wss" : "ws"
    this.showStatus("Connecting...")
    this.rfb = new RFB(this.screenTarget, `${scheme}://${window.location.host}${this.urlValue}`, { wsProtocols: ["binary"] })
    this.rfb.scaleViewport = true
    this.rfb.focusOnClick = true
    this.rfb.addEventListener("connect", () => this.hideStatus())
    this.rfb.addEventListener("disconnect", () => {
      if (this.closing) return
      this.showStatus("Connection lost — reconnecting...")
      this.retry = setTimeout(() => this.open(), 2000)
    })
  }

  showStatus(text) {
    this.statusTarget.textContent = text
    this.statusTarget.hidden = false
  }

  hideStatus() {
    this.statusTarget.hidden = true
  }
}
