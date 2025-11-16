import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tabs", "content"]

  connect() {
    console.log(this.contentTarget)
    this.tabsTarget.addEventListener("click", (event) => {
      event.preventDefault()
      this.tabsTarget.querySelectorAll(".tab").forEach((radio) => {
        radio.classList.remove("tab-active")
      })
      event.target.classList.add("tab-active")
      // Show loading spinner
      this.contentTarget.innerHTML = `<div class="flex items-center justify-center my-6">
        <span class="loading loading-spinner loading-sm"></span>
      </div>`
      this.contentTarget.src = event.target.href
    })
  }
}
