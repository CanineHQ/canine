import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "menuItem"]

  connect() {
    document.addEventListener('keydown', (e) => {
      // Check for Cmd+K (Mac) or Ctrl+K (Windows/Linux)
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault(); // Prevent default browser behavior
        this.searchModalToggle();
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

  searchModalToggle() {
    const searchInput = this.searchInputTarget;
    searchInput.focus();
    searchInput.value = "";
    const searchModal = document.getElementById("search_modal");
    searchModal.showModal();
    this._searchInput("");
  }

  _searchInput(term) {
    this.menuItemTargets.forEach(item => {
      const projectName = item.dataset.projectName;
      if (projectName.toLowerCase().includes(term.toLowerCase())) {
        item.setAttribute("open", "true");
        item.classList.remove("hidden");
      } else {
        item.removeAttribute("open");
        item.classList.add("hidden");
      }
    });
  }
  searchInput(event) {
    const search = event.target.value;
    this._searchInput(search);
  }
}
