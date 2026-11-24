import { Controller } from "@hotwired/stimulus"

// Full-screen screenshot browser for an agent session. The list of screenshots comes from the server (urlValue) when
// it opens, so it can browse all of them without the page loading them all; only the one showing and its neighbours
// are fetched. Clicking any image with data-lightbox-id opens it there. Arrow keys or the buttons step through,
// Escape or the backdrop closes it, and on a phone you can swipe. While it's open on a live session, new screenshots
// join the list as they arrive (the screen panel's "latest" marker is re-rendered with each one); if you were on the
// newest, it moves on to the new one.
export default class extends Controller {
  static targets = ["overlay", "image", "caption", "counter", "original", "latest", "explainer"]
  static values = { url: String }

  async open(event) {
    event.preventDefault()
    const id = Number(event.currentTarget.dataset.lightboxId)
    // A trigger can name its own screenshots source (the feed, where each post is a different session); otherwise the
    // controller's urlValue is used (a single session's page).
    this.currentUrl = event.currentTarget.dataset.lightboxUrl || this.urlValue
    await this.load()
    this.index = Math.max(0, this.items.findIndex((item) => item.id === id))
    this.overlayTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    this.show()
  }

  async load() {
    const response = await fetch(this.currentUrl || this.urlValue, { headers: { Accept: "application/json" } })
    this.items = await response.json()
  }

  // A new screenshot was broadcast into the page
  async latestTargetConnected() {
    if (!this.isOpen() || this.refreshing) return
    this.refreshing = true
    try {
      const following = this.index === this.items.length - 1
      const showing = this.items[this.index]?.id
      await this.load()
      const index = following ? this.items.length - 1 : this.items.findIndex((item) => item.id === showing)
      this.go(Math.max(0, index))
    } finally {
      this.refreshing = false
    }
  }

  isOpen() {
    return !this.overlayTarget.classList.contains("hidden")
  }

  close() {
    this.overlayTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  // Clicks on the dark backdrop close it; clicks on the image or controls don't
  backdrop(event) {
    if (event.target === this.overlayTarget) this.close()
  }

  next() {
    this.step(1)
  }

  previous() {
    this.step(-1)
  }

  keydown(event) {
    if (!this.isOpen()) return
    const moves = { ArrowRight: () => this.next(), ArrowLeft: () => this.previous(), Escape: () => this.close(),
                    Home: () => this.go(0), End: () => this.go(this.items.length - 1) }
    if (moves[event.key]) {
      event.preventDefault()
      moves[event.key]()
    }
  }

  touchstart(event) {
    this.touchX = event.touches[0].clientX
  }

  touchend(event) {
    const dx = event.changedTouches[0].clientX - this.touchX
    if (Math.abs(dx) > 50) this.step(dx < 0 ? 1 : -1)
  }

  async step(delta) {
    // At the end of a live session's list, check for screenshots that arrived since it opened
    if (this.index + delta >= this.items.length) await this.load()
    this.go(Math.min(this.items.length - 1, Math.max(0, this.index + delta)))
  }

  go(index) {
    this.index = index
    this.show()
  }

  show() {
    const item = this.items[this.index]
    if (!item) return
    this.imageTarget.src = item.src
    this.originalTarget.href = item.src
    this.captionTarget.textContent = item.caption
    this.counterTarget.textContent = `${this.index + 1} / ${this.items.length}`
    if (this.hasExplainerTarget) this.explain(item.explainer || [])
    // Load the neighbours, so stepping through is instant
    for (const neighbour of [this.items[this.index - 1], this.items[this.index + 1]]) {
      if (neighbour) new Image().src = neighbour.src
    }
  }

  // What the screenshot shows, as label/text rows under it
  explain(rows) {
    this.explainerTarget.replaceChildren(...rows.flatMap(([label, text]) => {
      const term = document.createElement("dt")
      term.className = "text-white/50"
      term.textContent = label
      const detail = document.createElement("dd")
      detail.className = label === "Error" ? "text-error break-words" : "break-words"
      detail.textContent = text
      return [term, detail]
    }))
  }
}
