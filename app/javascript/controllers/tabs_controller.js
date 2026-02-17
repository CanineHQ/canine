import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  select(event) {
    event.preventDefault()
    const selectedTab = event.currentTarget.dataset.tab

    this.tabTargets.forEach((tab) => {
      tab.classList.toggle("tab-active", tab.dataset.tab === selectedTab)
    })

    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.tab !== selectedTab)
    })
  }
}
