import { Controller } from "@hotwired/stimulus"

const NARROW_WIDTH = 768;
export default class extends Controller {
  static targets = ["searchInput", "menuItem", "linkItem"]

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

    document.addEventListener('keydown', (e) => {
      // Check for Cmd+K (Mac) or Ctrl+K (Windows/Linux)
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault(); // Prevent default browser behavior
        this.searchModalToggle();
      }
    });

    // Add keyboard navigation event listener
    document.addEventListener('keydown', (e) => {
      const searchModal = document.getElementById("search_modal");
      if (!searchModal.open) return;
      
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault();
        this.handleArrowNavigation(e.key === 'ArrowDown');
      } else if (e.key === 'Enter') {
        e.preventDefault();
        const activeLink = this.linkItemTargets.find(link => 
          link.classList.contains('active')
        );
        if (activeLink) {
          window.location.href = activeLink.href;
        }
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
    const searchModal = document.getElementById("search_modal");
    
    // If modal is already open, close it and return
    if (searchModal.open) {
      searchModal.close();
      return;
    }

    // Otherwise, proceed with opening the modal
    const searchInput = this.searchInputTarget;
    searchInput.focus();
    searchInput.value = "";
    searchModal.showModal();
    this._searchInput("");
  }

  _searchInput(term) {
    this.menuItemTargets.forEach(item => {
      const projectName = item.dataset.projectName;
      if (projectName.toLowerCase().includes(term.toLowerCase())) {
        item.setAttribute("open", "true");
        item.classList.remove("hidden");
        
        // Add underlining for matching text
        if (term) {
          const regex = new RegExp(`(${term})`, 'gi');
          const highlightedText = projectName.replace(regex, '<span class="search-highlight">$1</span>');
          item.querySelector('.project-name').innerHTML = highlightedText;
        } else {
          item.querySelector('.project-name').textContent = projectName;
        }
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

  handleArrowNavigation(isDownArrow) {
    const visibleLinks = this.linkItemTargets.filter(link => 
      !link.closest('.hidden')
    );
    
    if (!visibleLinks.length) return;
    
    const currentIndex = visibleLinks.findIndex(link => 
      link.classList.contains('active')
    );
    
    // Remove existing selection
    visibleLinks.forEach(link => link.classList.remove('active'));
    
    let newIndex;
    if (currentIndex === -1) {
      // No current selection, start at first/last item
      newIndex = isDownArrow ? 0 : visibleLinks.length - 1;
    } else {
      // Move up or down
      newIndex = isDownArrow
        ? (currentIndex + 1) % visibleLinks.length
        : (currentIndex - 1 + visibleLinks.length) % visibleLinks.length;
    }
    
    visibleLinks[newIndex].classList.add('active');
  }
}
