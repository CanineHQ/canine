import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body", "steps"]
  static values = {
    lines: { type: Array, default: [] },
    interval: { type: Number, default: 700 },
    autoplay: { type: Boolean, default: false },
    loop: { type: Boolean, default: false },
    loopDelay: { type: Number, default: 3000 },
  }

  connect() {
    if (this.autoplayValue && this.hasStepsTarget) {
      this._observer = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            this.play()
            this._observer.disconnect()
          }
        })
      }, { threshold: 0.3 })
      this._observer.observe(this.stepsTarget)
    }
  }

  disconnect() {
    if (this._observer) this._observer.disconnect()
    this._clearTimers()
  }

  play() {
    if (!this.hasStepsTarget) return
    this._clearTimers()
    this.stepsTarget.innerHTML = ''
    const body = this.hasBodyTarget ? this.bodyTarget : null

    this._timers = this.linesValue.map((line, i) =>
      setTimeout(() => {
        const p = document.createElement('p')
        p.style.color = line.color
        p.style.marginTop = '8px'
        p.innerHTML = line.text
        this.stepsTarget.appendChild(p)
        if (body) body.scrollTop = body.scrollHeight
      }, i * this.intervalValue)
    )

    if (this.loopValue) {
      const totalDuration = (this.linesValue.length - 1) * this.intervalValue + this.loopDelayValue
      this._loopTimer = setTimeout(() => this.play(), totalDuration)
    }
  }

  _clearTimers() {
    if (this._timers) this._timers.forEach(clearTimeout)
    if (this._loopTimer) clearTimeout(this._loopTimer)
    this._timers = []
    this._loopTimer = null
  }
}
