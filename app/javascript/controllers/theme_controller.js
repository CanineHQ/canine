import { Controller } from "@hotwired/stimulus"

const NARROW_WIDTH = 768;
export default class extends Controller {
  connect() {
    const html = document.querySelector("html");
    // If the window is narrow, hide the left bar and set mobile mode
    if (window.innerWidth < NARROW_WIDTH) {
      html.setAttribute("data-leftbar-hide", "true");
      html.setAttribute("data-leftbar-type", "mobile");
    }
    // Also, if the window is resized, check again
    window.addEventListener("resize", () => {
      if (window.innerWidth < NARROW_WIDTH) {
        html.setAttribute("data-leftbar-hide", "true");
        html.setAttribute("data-leftbar-type", "mobile");
      } else {
        html.removeAttribute("data-leftbar-hide");
        html.removeAttribute("data-leftbar-type");
      }
    });
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
