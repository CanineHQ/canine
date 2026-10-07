import { Controller } from "@hotwired/stimulus"

// A day heading in the agent feed, shown only where a new day starts, in the browser's time zone: "Today",
// "Yesterday", the weekday within the week, then the date. Each post has one; pages load in order as the feed
// scrolls, so the heading before this one is already on the page.
export default class extends Controller {
  static values = { at: String }
  static targets = ["label"]

  connect() {
    const day = this.dayOf(new Date(this.atValue))
    this.element.dataset.day = day.toDateString()
    const headings = [...document.querySelectorAll("[data-controller~='feed-day']")]
    const previous = headings[headings.indexOf(this.element) - 1]
    if (previous && previous.dataset.day === this.element.dataset.day) return

    this.labelTarget.textContent = this.label(day)
    this.element.classList.replace("hidden", "flex")
  }

  dayOf(time) {
    return new Date(time.getFullYear(), time.getMonth(), time.getDate())
  }

  label(day) {
    const today = this.dayOf(new Date())
    const daysAgo = Math.round((today - day) / 86400000)
    if (daysAgo === 0) return "Today"
    if (daysAgo === 1) return "Yesterday"
    if (daysAgo < 7) return day.toLocaleDateString(undefined, { weekday: "long" })
    const year = day.getFullYear() === today.getFullYear() ? undefined : "numeric"
    return day.toLocaleDateString(undefined, { weekday: "short", day: "numeric", month: "short", year })
  }
}
