import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tabs", "content"]

  connect() {
    this.clickHandler = (event) => {
      event.preventDefault()
      this.tabsTarget.querySelectorAll(".tab").forEach((radio) => {
        radio.classList.remove("tab-active")
      })
      event.target.classList.add("tab-active")
      this.contentTarget.innerHTML = `<div class="flex items-center justify-center my-6" style="height: 300px;">
        <span class="loading loading-spinner loading-sm"></span>
      </div>`
      this.contentTarget.src = event.target.href
    }
    this.tabsTarget.addEventListener("click", this.clickHandler)
  }

  disconnect() {
    this.tabsTarget.removeEventListener("click", this.clickHandler)
  }
}
