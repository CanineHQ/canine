import BaseDropdownController from "./base_dropdown_controller"
import { debounce } from "../../utils"

/**
 * Controller for async search dropdowns with autocomplete
 *
 * Child controllers must implement:
 * - fetchResults(query): Promise<Array> - Fetch and return search results
 * - renderItem(item): String - Return HTML string for a single item
 * - onItemSelect(item, itemElement): void - Handle item selection
 *
 * Optional overrides:
 * - getInputElement(): HTMLElement - Get the input element (default: finds input in this.element)
 * - shouldSearch(query): Boolean - Determine if search should be performed (default: non-empty query)
 * - getDebounceDelay(): Number - Debounce delay in ms (default: 500)
 */
export default class extends BaseDropdownController {
  connect() {
    super.connect()

    this.inputElement = this.getInputElement()

    if (!this.inputElement) {
      console.error('AsyncSearchDropdown: No input element found')
      return
    }

    this.inputElement.setAttribute('autocomplete', 'off')

    this.searchHandler = debounce(this.performSearch.bind(this), this.getDebounceDelay())
    this.inputElement.addEventListener('input', this.searchHandler)
    this.inputElement.addEventListener('keydown', this.handleKeydown.bind(this))
  }

  disconnect() {
    if (this.inputElement) {
      this.inputElement.removeEventListener('input', this.searchHandler)
      this.inputElement.removeEventListener('keydown', this.handleKeydown.bind(this))
    }
    super.disconnect()
  }

  getInputElement() {
    return this.element.querySelector('input')
  }

  getDebounceDelay() {
    return 500
  }

  shouldSearch(query) {
    return query.trim().length > 0
  }

  async performSearch() {
    const query = this.inputElement.value

    if (!this.shouldSearch(query)) {
      this.hideDropdown()
      return
    }

    try {
      this.showLoading()
      const results = await this.fetchResults(query)
      this.renderResults(results)
    } catch (error) {
      console.error('Search error:', error)
      this.showError(error.message || 'Failed to fetch results')
    }
  }

  renderResults(results) {
    if (!results || results.length === 0) {
      this.showEmpty()
      return
    }

    this.dropdown.innerHTML = results.map((item, index) => `
      <li class="cursor-pointer p-4 hover:bg-base-300" data-index="${index}">
        ${this.renderItem(item)}
      </li>
    `).join('')

    this.currentResults = results

    this.dropdown.querySelectorAll('li').forEach((li, index) => {
      li.addEventListener('click', () => {
        this.selectItem(results[index], li)
      })
      li.addEventListener('mouseenter', () => {
        this.highlightItem(index)
      })
    })

    this.showDropdown()
  }

  selectItem(item, itemElement) {
    this.onItemSelect(item, itemElement)
    this.clearInput()
    this.hideDropdown()
  }

  selectItemAtIndex(index) {
    if (this.currentResults && this.currentResults[index]) {
      const li = this.dropdown.querySelectorAll('li[data-index]')[index]
      this.selectItem(this.currentResults[index], li)
    }
  }

  clearInput() {
    if (this.inputElement) {
      this.inputElement.value = ''
    }
  }

  // Methods to be implemented by child controllers
  async fetchResults(query) {
    throw new Error('fetchResults must be implemented by child controller')
  }

  renderItem(item) {
    throw new Error('renderItem must be implemented by child controller')
  }

  onItemSelect(item, itemElement) {
    throw new Error('onItemSelect must be implemented by child controller')
  }
}
