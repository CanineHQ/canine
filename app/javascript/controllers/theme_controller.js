import { Controller } from "@hotwired/stimulus"

const NARROW_WIDTH = 768;
export default class extends Controller {
  connect() {
    // If the window is narrow, hide the left bar
    if (window.innerWidth < NARROW_WIDTH) {
      document.querySelector("html").setAttribute("data-leftbar-hide", "true");
    }
    // Also, if the window is resized, check again
    window.addEventListener("resize", () => {
      if (window.innerWidth < NARROW_WIDTH) {
        document.querySelector("html").setAttribute("data-leftbar-hide", "true");
      } else {
        document.querySelector("html").removeAttribute("data-leftbar-hide");
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
