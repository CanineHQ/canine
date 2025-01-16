import { Controller } from "@hotwired/stimulus"
import { renderHelmChartCard } from "../utils/helm_charts"

export default class extends Controller {
  static values = {
    chartName: String
  }

  connect() {
    this.input = this.element.querySelector(`input[name="add_on[metadata][${this.chartNameValue}][helm_chart.name]"]`)
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

    const url = `/add_ons/search?q=${this.input.value}`
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
      <li class="p-2 cursor-pointer" data-package-name="${pkg.name}" data-package-data='${JSON.stringify(pkg)}'>
        <div class="font-medium block">
          ${pkg.name}
          <br/>
          <div class="text-sm text-base-content/70">${pkg.description}</div>
        </div>
      </li>
    `).join('')

    // Add click handlers to all list items
    this.dropdown.querySelectorAll('li').forEach(li => {
      li.addEventListener('click', () => {
        this.input.parentElement.classList.add('hidden')
        this.input.value = li.dataset.packageName
        const packageData = JSON.parse(li.dataset.packageData);
        this.hideDropdown()
        this.element.querySelector(`input[name="add_on[metadata][${this.chartNameValue}][package_id]"]`).value = packageData.package_id
        this.element.appendChild(renderHelmChartCard(packageData))
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