import AsyncSearchDropdownController from "./components/async_search_dropdown_controller"
import { renderHelmChartCard, helmChartHeader } from "../utils/helm_charts"

export default class extends AsyncSearchDropdownController {
  static values = {
    chartName: String
  }

  getInputElement() {
    return this.element.querySelector(`input[name="add_on[metadata][helm_chart][helm_chart.name]"]`)
  }

  async fetchResults(query) {
    const response = await fetch(`/add_ons/search?q=${encodeURIComponent(query)}`)
    if (!response.ok) {
      throw new Error('Failed to fetch helm charts')
    }
    const data = await response.json()
    return data.packages
  }

  renderItem(pkg) {
    return helmChartHeader(pkg)
  }

  onItemSelect(pkg, itemElement) {
    this.input.parentElement.classList.add('hidden')
    this.input.value = pkg.name
    const chartUrl = `${pkg.repository.name}/${pkg.name}`
    document.querySelector(`input[name="add_on[chart_url]"]`).value = chartUrl
    this.element.appendChild(renderHelmChartCard(pkg))
  }
}