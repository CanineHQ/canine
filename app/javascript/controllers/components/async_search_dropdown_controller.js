import { Controller } from "@hotwired/stimulus"
import { debounce } from "../../utils"

/**
 * Base controller for async search dropdowns with autocomplete
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
export default class extends Controller {
  connect() {
    this.input = this.getInputElement()

    if (!this.input) {
      console.error('AsyncSearchDropdown: No input element found')
      return
    }

    // Disable browser autocomplete
    this.input.setAttribute('autocomplete', 'off')

    // Create dropdown
    this.dropdown = this.createDropdown()
    this.element.appendChild(this.dropdown)

    // Bind search handler with debounce
    this.searchHandler = debounce(this.performSearch.bind(this), this.getDebounceDelay())
    this.input.addEventListener('input', this.searchHandler)

    // Handle click outside to close dropdown
    this.clickOutsideHandler = this.handleClickOutside.bind(this)
    document.addEventListener('click', this.clickOutsideHandler)
  }

  disconnect() {
    if (this.input) {
      this.input.removeEventListener('input', this.searchHandler)
    }
    document.removeEventListener('click', this.clickOutsideHandler)
  }

  createDropdown() {
    const dropdown = document.createElement('ul')
    dropdown.className = 'hidden absolute z-10 w-full mt-1 menu bg-base-200 block rounded-box shadow-lg max-h-[300px] overflow-y-auto'
    return dropdown
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
    const query = this.input.value

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
      <li class="cursor-pointer hover:bg-base-300 p-2" data-index="${index}">
        ${this.renderItem(item)}
      </li>
    `).join('')

    // Store results for later access
    this.currentResults = results

    // Add click handlers
    this.dropdown.querySelectorAll('li').forEach((li, index) => {
      li.addEventListener('click', () => {
        this.selectItem(results[index], li)
      })
    })

    this.showDropdown()
  }

  selectItem(item, itemElement) {
    this.onItemSelect(item, itemElement)
    this.clearInput()
    this.hideDropdown()
  }

  clearInput() {
    if (this.input) {
      this.input.value = ''
    }
  }

  showDropdown() {
    this.dropdown.classList.remove('hidden')
  }

  hideDropdown() {
    this.dropdown.classList.add('hidden')
    this.dropdown.innerHTML = ''
  }

  showLoading() {
    this.dropdown.innerHTML = `
      <li class="p-4 text-center flex items-center justify-center gap-2">
        <span class="loading loading-spinner loading-sm"></span>
        <span>Searching...</span>
      </li>
    `
    this.showDropdown()
  }

  showError(message) {
    this.dropdown.innerHTML = `
      <li class="p-4 text-center text-error">
        ${message}
      </li>
    `
    this.showDropdown()
  }

  showEmpty() {
    this.dropdown.innerHTML = `
      <li class="p-4 text-center text-base-content/60">
        No results found
      </li>
    `
    this.showDropdown()
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideDropdown()
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
