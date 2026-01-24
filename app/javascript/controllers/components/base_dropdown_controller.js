import { Controller } from "@hotwired/stimulus"
import { computePosition, autoUpdate, flip, shift, offset, size } from "@floating-ui/dom"

/**
 * Base controller for dropdown components with positioning and keyboard navigation
 *
 * Provides:
 * - Dropdown creation and floating-ui positioning
 * - Show/hide with auto-update on scroll/resize
 * - Click outside to close
 * - Keyboard navigation (arrow keys, enter, escape)
 * - Empty/loading/error states
 * - Selected item display with clear functionality
 *
 * Child controllers should:
 * - Call super.connect() and super.disconnect()
 * - Set this.inputElement to the input element
 * - Optionally set this.selectedDisplay to show selected items
 * - Override getItems() to return selectable items
 * - Override onItemSelect(item) to handle selection
 */
export default class extends Controller {
  connect() {
    this.dropdown = this.createDropdown()
    this.getDropdownContainer().appendChild(this.dropdown)

    this.clickOutsideHandler = this.handleClickOutside.bind(this)
    document.addEventListener('click', this.clickOutsideHandler)

    this.cleanupAutoUpdate = null
    this.highlightedIndex = -1
  }

  disconnect() {
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
    dropdown.className = 'hidden z-50 bg-neutral rounded-box shadow-lg max-h-[300px] overflow-y-auto'
    dropdown.style.position = 'absolute'
    dropdown.style.top = '0'
    dropdown.style.left = '0'
    return dropdown
  }

  getDropdownContainer() {
    const modal = this.element.closest('.modal, [role="dialog"], dialog')
    return modal || document.body
  }

  updatePosition() {
    if (!this.inputElement) return

    computePosition(this.inputElement, this.dropdown, {
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

  showDropdown() {
    this.dropdown.classList.remove('hidden')
    this.updatePosition()

    if (this.cleanupAutoUpdate) {
      this.cleanupAutoUpdate()
    }
    this.cleanupAutoUpdate = autoUpdate(this.inputElement, this.dropdown, () => {
      this.updatePosition()
    })
  }

  hideDropdown() {
    this.dropdown.classList.add('hidden')
    this.highlightedIndex = -1

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

  showEmpty(message = 'No results found') {
    this.dropdown.innerHTML = `
      <li class="p-4 text-center text-base-content/60">
        ${message}
      </li>
    `
    this.showDropdown()
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target) && !this.dropdown.contains(event.target)) {
      this.hideDropdown()
    }
  }

  // Keyboard navigation
  handleKeydown(event) {
    const items = this.dropdown.querySelectorAll('li[data-index]')

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault()
        if (this.dropdown.classList.contains('hidden')) {
          this.onInputFocus?.()
        } else {
          this.highlightItem(Math.min(this.highlightedIndex + 1, items.length - 1))
          this.scrollToHighlighted()
        }
        break
      case 'ArrowUp':
        event.preventDefault()
        this.highlightItem(Math.max(this.highlightedIndex - 1, 0))
        this.scrollToHighlighted()
        break
      case 'Enter':
        event.preventDefault()
        if (this.highlightedIndex >= 0 && items[this.highlightedIndex]) {
          this.selectItemAtIndex(this.highlightedIndex)
        }
        break
      case 'Escape':
        this.hideDropdown()
        break
    }
  }

  highlightItem(index) {
    const items = this.dropdown.querySelectorAll('li[data-index]')
    items.forEach((item, i) => {
      item.classList.toggle('bg-base-300', i === index)
    })
    this.highlightedIndex = index
  }

  scrollToHighlighted() {
    const items = this.dropdown.querySelectorAll('li[data-index]')
    const highlighted = items[this.highlightedIndex]
    if (highlighted) {
      highlighted.scrollIntoView({ block: 'nearest' })
    }
  }

  // Selected item display methods
  // Requires: this.inputElement, this.selectedDisplay, this.hiddenInput (optional)
  showSelectedItem(html, value) {
    if (!this.selectedDisplay) return

    this.selectedDisplay.innerHTML = html
    this.selectedDisplay.classList.remove('hidden')

    if (this.inputElement) {
      this.inputElement.classList.add('hidden')
      this.inputElement.value = ''
    }

    if (this.hiddenInput) {
      this.hiddenInput.value = value
    }

    this.hideDropdown()
  }

  clearSelection() {
    if (this.selectedDisplay) {
      this.selectedDisplay.innerHTML = ''
      this.selectedDisplay.classList.add('hidden')
    }

    if (this.inputElement) {
      this.inputElement.classList.remove('hidden')
      this.inputElement.value = ''
      this.inputElement.focus()
    }

    if (this.hiddenInput) {
      this.hiddenInput.value = ''
    }

    this.dispatch('clear')
  }

  // To be implemented by child controllers
  selectItemAtIndex(index) {
    throw new Error('selectItemAtIndex must be implemented by child controller')
  }
}
