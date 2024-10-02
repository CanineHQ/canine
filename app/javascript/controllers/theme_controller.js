import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Theme controller connected")
  }

  leftbarToggle() {
    const html = document.querySelector("html");
    if (html.hasAttribute("data-leftbar-hide")) {
      html.removeAttribute("data-leftbar-hide")
    } else {
      html.setAttribute("data-leftbar-hide", "true")
    }
  }
}
