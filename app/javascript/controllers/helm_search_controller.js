import { Controller } from "@hotwired/stimulus"
import { renderHelmChartCard, helmChartHeader } from "../utils/helm_charts"
import { debounce } from "../utils"

export default class extends Controller {
  static values = {
    chartName: String
  }

  connect() {
    this.input = this.element.querySelector(`input[name="add_on[metadata][helm_chart][helm_chart.name]"]`)
    // disable autocomplete
    this.input.setAttribute('autocomplete', 'off')
    
    // Create and append dropdown
    this.dropdown = document.createElement('ul')
    this.dropdown.className = 'hidden absolute z-10 w-full mt-1 menu bg-base-200 block rounded-box shadow-lg max-h-[300px] overflow-y-auto'
    this.element.appendChild(this.dropdown)
    
    // Bind search handler with debounce
    this.input.addEventListener('input', debounce(this.performSearch.bind(this), 500));
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
      <li class="p-2" data-package-name="${pkg.name}" data-package-data="${encodeURIComponent(JSON.stringify(pkg))}">
        ${helmChartHeader(pkg)}
      </li>
    `).join('')

    // Add click handlers to all list items
    this.dropdown.querySelectorAll('li').forEach(li => {
      li.addEventListener('click', () => {
        this.input.parentElement.classList.add('hidden')
        this.input.value = li.dataset.packageName
        const packageData = JSON.parse(decodeURIComponent(li.dataset.packageData));
        this.hideDropdown()
        const chartUrl = `${packageData.repository.name}/${packageData.name}`
        document.querySelector(`input[name="add_on[chart_url]"]`).value = chartUrl
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