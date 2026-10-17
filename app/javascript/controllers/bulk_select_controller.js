import { Controller } from "@hotwired/stimulus"

// Checkbox selection for bulk actions on a paginated list. Checking every row on the page offers to extend the
// selection to every matching record (allMatching), including those on other pages.
export default class extends Controller {
  static targets = ["all", "row", "action", "banner", "offer", "selected", "allMatching"]

  connect() {
    this.update()
  }

  toggleAll() {
    this.rowTargets.forEach((row) => (row.checked = this.allTarget.checked))
    this.update()
  }

  selectAllMatching() {
    this.allMatchingTarget.value = "1"
    this.update()
  }

  clear() {
    this.allTarget.checked = false
    this.toggleAll()
  }

  update() {
    const checked = this.rowTargets.filter((row) => row.checked).length
    const pageSelected = checked > 0 && checked === this.rowTargets.length
    if (!pageSelected) this.allMatchingTarget.value = "0"
    const allMatching = this.allMatchingTarget.value === "1"

    this.allTarget.checked = pageSelected
    this.allTarget.indeterminate = checked > 0 && !pageSelected
    this.actionTargets.forEach((button) => (button.disabled = checked === 0 || button.dataset.current === "true"))

    if (this.hasBannerTarget) {
      this.bannerTarget.hidden = !pageSelected
      this.offerTarget.hidden = allMatching
      this.selectedTarget.hidden = !allMatching
    }
  }
}
