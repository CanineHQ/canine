import { Controller } from "@hotwired/stimulus"
import { computePosition, autoUpdate, flip, shift, offset, size } from "@floating-ui/dom"
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

    // Create dropdown and append to the appropriate container
    this.dropdown = this.createDropdown()
    this.getDropdownContainer().appendChild(this.dropdown)

    // Bind search handler with debounce
    this.searchHandler = debounce(this.performSearch.bind(this), this.getDebounceDelay())
    this.input.addEventListener('input', this.searchHandler)

    // Handle click outside to close dropdown
    this.clickOutsideHandler = this.handleClickOutside.bind(this)
    document.addEventListener('click', this.clickOutsideHandler)

    this.cleanupAutoUpdate = null
  }

  disconnect() {
    if (this.input) {
      this.input.removeEventListener('input', this.searchHandler)
    }
    document.removeEventListener('click', this.clickOutsideHandler)
    if (this.cleanupAutoUpdate) {
      this.cleanupAutoUpdate()
    }
    if (this.dropdown && this.dropdown.parentNode) {
      this.dropdown.parentNode.removeChild(this.dropdown)
    }
  }

  createDropdown() {
    const dropdown = document.createElement('ul')
    dropdown.className = 'hidden z-50 menu bg-neutral rounded-box shadow-lg max-h-[300px] overflow-y-auto'
    dropdown.style.position = 'absolute'
    dropdown.style.top = '0'
    dropdown.style.left = '0'
    return dropdown
  }

  getDropdownContainer() {
    // Check if we're inside a modal and append there to maintain stacking context
    const modal = this.element.closest('.modal, [role="dialog"], dialog')
    return modal || document.body
  }

  updatePosition() {
    computePosition(this.input, this.dropdown, {
      placement: 'bottom-start',
      middleware: [
        offset(4),
        flip({ fallbackPlacements: ['top-start'] }),
        shift({ padding: 8 }),
        size({
          apply({ rects, elements }) {
            Object.assign(elements.floating.style, {
              minWidth: `${rects.reference.width}px`
            })
          }
        })
      ]
    }).then(({ x, y }) => {
      Object.assign(this.dropdown.style, {
        left: `${x}px`,
        top: `${y}px`
      })
    })
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
    this.updatePosition()

    // Set up auto-update to keep position in sync during scroll/resize
    if (this.cleanupAutoUpdate) {
      this.cleanupAutoUpdate()
    }
    this.cleanupAutoUpdate = autoUpdate(this.input, this.dropdown, () => {
      this.updatePosition()
    })
  }

  hideDropdown() {
    this.dropdown.classList.add('hidden')
    this.dropdown.innerHTML = ''

    // Clean up auto-update listener
    if (this.cleanupAutoUpdate) {
      this.cleanupAutoUpdate()
      this.cleanupAutoUpdate = null
    }
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
    if (!this.element.contains(event.target) && !this.dropdown.contains(event.target)) {
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
