import { Controller } from "@hotwired/stimulus"

// Opens what a link into a session points at (from the agent feed): the step in the URL's #hash, with the chapter
// around it, scrolled to and highlighted; and with ?shot=<action id>, that action's screenshot once the step's
// contents have loaded (they load lazily, when the step opens)
export default class extends Controller {
  connect() {
    const target = window.location.hash && document.getElementById(window.location.hash.slice(1))
    if (!target) return

    this.open(target)
    this.highlight(target)
    const shot = new URLSearchParams(window.location.search).get("shot")
    if (shot) this.openShot(target, shot)
  }

  open(element) {
    for (let node = element; node && node !== this.element; node = node.parentElement) {
      if (node.tagName === "DETAILS") node.open = true
    }
    element.querySelector(":scope > details")?.setAttribute("open", "")
  }

  highlight(element) {
    element.scrollIntoView({ block: "start", behavior: "smooth" })
    element.classList.add("ring-2", "ring-primary")
    setTimeout(() => element.classList.remove("ring-2", "ring-primary"), 4000)
  }

  openShot(step, id) {
    const show = () => {
      const action = document.getElementById(`agent_session_action_${id}`)
      if (!action) return false
      this.open(action)
      action.querySelector(":scope > details")?.setAttribute("open", "")
      action.scrollIntoView({ block: "center", behavior: "smooth" })
      return true
    }
    if (show()) return
    step.addEventListener("turbo:frame-load", () => show(), { once: true })
  }
}
