import { Controller } from "@hotwired/stimulus"
import LocalTime from "local-time"

// Hourly event bars: hovering, focusing or tapping a bar shows its count and hour (in the browser's time zone) in the
// caption, which otherwise shows the total. Tapping matters on phones, where title tooltips never appear.
export default class extends Controller {
  static targets = ["bar", "caption"]

  connect() {
    this.summary = this.captionTarget.textContent
    this.barTargets.forEach((bar) => bar.setAttribute("aria-label", this.label(bar)))
  }

  show(event) {
    this.barTargets.forEach((bar) => bar.setAttribute("aria-pressed", bar === event.currentTarget))
    this.captionTarget.textContent = this.label(event.currentTarget)
  }

  reset() {
    this.barTargets.forEach((bar) => bar.setAttribute("aria-pressed", false))
    this.captionTarget.textContent = this.summary
  }

  label(bar) {
    return `${bar.dataset.count} · ${LocalTime.strftime(new Date(bar.dataset.time), "%b %e %l%P")}`
  }
}
