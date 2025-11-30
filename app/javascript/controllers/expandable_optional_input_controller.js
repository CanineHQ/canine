import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    // Initial setup: hidden + transparent + transition classes
    this.containerTarget.classList.add(
      "hidden",          // prevent layout
      "opacity-0",       // starting transparency
      "transition-all",
      "duration-500"     // control speed
    )
  }

  show(e) {
    e.preventDefault()

    // Hide the button
    e.target.classList.add("hidden")

    // Step 1: unhide but keep opacity-0
    this.containerTarget.classList.remove("hidden")

    // Step 2: allow browser to register this initial state
    requestAnimationFrame(() => {
      // Step 3: now fade to opacity-100 → animation occurs
      this.containerTarget.classList.add("opacity-100")
      this.containerTarget.classList.remove("opacity-0")
    })
  }
}
