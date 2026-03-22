import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mobileMenu"]

  toggleMobile() {
    this.mobileMenuTarget.classList.toggle("hidden")
    document.body.classList.toggle("overflow-hidden")
  }
}
