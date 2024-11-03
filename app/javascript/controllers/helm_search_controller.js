import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.input = this.element.querySelector('input')
    this.debounceTimer = null
    
    // Create and append dropdown
    this.dropdown = document.createElement('ul')
    this.dropdown.className = 'hidden absolute z-10 w-full mt-1 menu bg-base-100 rounded-box shadow-lg'
    this.element.appendChild(this.dropdown)
    
    // Bind search handler with debounce
    this.input.addEventListener('input', () => {
      clearTimeout(this.debounceTimer)
      this.debounceTimer = setTimeout(() => this.performSearch(), 500)
    })
  }

  async performSearch() {
    if (!this.input.value.trim()) {
      this.hideDropdown()
      return
    }

    const url = `https://artifacthub.io/api/v1/packages/search?ts_query_web=${this.input.value}&facets=false&sort=relevance&limit=5&offset=0`
    const response = await fetch(url)
    const data = await response.json()
    
    this.renderResults(data.packages)
  }

  renderResults(packages) {
    if (!packages.length) {
      this.hideDropdown()
      return
    }

    this.dropdown.innerHTML = packages.map(pkg => `
      <li class="hover:bg-base-200 p-2 cursor-pointer" data-package-name="${pkg.name}">
        <div class="font-medium">
          ${pkg.name}
          <br/>
          <div class="text-sm text-base-content/70">${pkg.description}</div>
        </div>
      </li>
    `).join('')

    // Add click handlers to all list items
    this.dropdown.querySelectorAll('li').forEach(li => {
      li.addEventListener('click', () => {
        this.input.value = li.dataset.packageName
        this.hideDropdown()
      })
    })

    this.showDropdown()
  }

  showDropdown() {
    this.dropdown.classList.remove('hidden')
  }

  hideDropdown() {
    this.dropdown.classList.add('hidden')
  }
}