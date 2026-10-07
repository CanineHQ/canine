import { Controller } from "@hotwired/stimulus"

// "running for 1m 23s", ticking every second until the session finishes ("took 4m 10s")
export default class extends Controller {
  static values = { from: String, to: String }

  connect() {
    this.render()
    if (!this.toValue) this.timer = setInterval(() => this.render(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  render() {
    const end = this.toValue ? new Date(this.toValue) : new Date()
    const seconds = Math.max(0, Math.round((end - new Date(this.fromValue)) / 1000))
    const text = seconds >= 60 ? `${Math.floor(seconds / 60)}m ${seconds % 60}s` : `${seconds}s`
    this.element.textContent = this.toValue ? `took ${text}` : `running for ${text}`
  }
}
