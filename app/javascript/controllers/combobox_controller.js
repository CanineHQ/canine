import BaseDropdownController from "./components/base_dropdown_controller"
import { debounce } from "../utils"

/**
 * Combobox controller for searchable dropdown with static items
 *
 * Usage:
 * <div data-controller="combobox">
 *   <input type="text" data-combobox-target="input" />
 *   <input type="hidden" data-combobox-target="hidden" />
 *   <div data-combobox-target="selected" class="hidden"></div>
 *   <template data-combobox-target="template">
 *     <ul>
 *       <li data-combobox-target="item" data-value="1" data-display-text="Item 1">Item 1</li>
 *     </ul>
 *   </template>
 * </div>
 */
export default class extends BaseDropdownController {
  static targets = ["input", "hidden", "template", "item", "selected"]

  connect() {
    super.connect()

    if (!this.hasInputTarget) {
      console.error('Combobox: No input target found')
      return
    }

    this.inputElement = this.inputTarget
    this.hiddenInput = this.hasHiddenTarget ? this.hiddenTarget : null
    this.selectedDisplay = this.hasSelectedTarget ? this.selectedTarget : null

    this.inputElement.setAttribute('autocomplete', 'off')

    this.filterHandler = debounce(this.filter.bind(this), 150)
    this.inputElement.addEventListener('input', this.filterHandler)
    this.inputElement.addEventListener('focus', this.onInputFocus.bind(this))
    this.inputElement.addEventListener('keydown', this.handleKeydown.bind(this))

    // If there's already a selected value, show it
    if (this.hiddenInput?.value && this.selectedDisplay) {
      this.showInitialSelection()
    }
  }

  disconnect() {
    if (this.inputElement) {
      this.inputElement.removeEventListener('input', this.filterHandler)
      this.inputElement.removeEventListener('focus', this.onInputFocus.bind(this))
      this.inputElement.removeEventListener('keydown', this.handleKeydown.bind(this))
    }
    super.disconnect()
  }

  showInitialSelection() {
    const value = this.hiddenInput.value
    const items = this.getSourceItems()
    const selectedItem = items.find(item => item.dataset.value === value)

    if (selectedItem) {
      this.showSelectedItem(this.buildSelectedHtml(selectedItem.innerHTML), value)
    }
  }

  onInputFocus() {
    this.showAllItems()
  }

  filter() {
    const query = this.inputElement.value.toLowerCase().trim()

    if (!query) {
      this.showAllItems()
      return
    }

    const items = this.getSourceItems()
    const filtered = items.filter(item => {
      const searchText = item.dataset.searchText || item.textContent
      return searchText.toLowerCase().includes(query)
    })

    this.renderItems(filtered)
  }

  showAllItems() {
    this.renderItems(this.getSourceItems())
  }

  getSourceItems() {
    if (this.hasTemplateTarget) {
      const content = this.templateTarget.content.cloneNode(true)
      return Array.from(content.querySelectorAll('[data-combobox-target="item"]'))
    }
    return this.itemTargets
  }

  renderItems(items) {
    this.dropdown.innerHTML = ''
    this.highlightedIndex = -1
    this.currentItems = items

    if (items.length === 0) {
      this.showEmpty()
      return
    }

    items.forEach((item, index) => {
      const li = document.createElement('li')
      li.className = 'cursor-pointer p-4 hover:bg-base-300'
      li.dataset.index = index
      li.dataset.value = item.dataset.value
      li.innerHTML = item.innerHTML

      li.addEventListener('click', () => this.selectItem(li))
      li.addEventListener('mouseenter', () => this.highlightItem(index))

      this.dropdown.appendChild(li)
    })

    this.showDropdown()
  }

  selectItem(itemElement) {
    const value = itemElement.dataset.value
    const html = this.buildSelectedHtml(itemElement.innerHTML)

    this.showSelectedItem(html, value)
    this.dispatch('select', { detail: { value, element: itemElement } })
  }

  buildSelectedHtml(innerHtml) {
    return `
      <div class="flex items-center justify-between gap-2 p-3 border border-base-300 rounded-lg bg-base-100">
        <div class="flex-1 min-w-0">${innerHtml}</div>
        <button type="button" class="btn btn-ghost btn-xs btn-circle" data-action="combobox#clear" aria-label="Clear selection">
          <iconify-icon icon="lucide:x" width="16" height="16"></iconify-icon>
        </button>
      </div>
    `
  }

  clear(event) {
    event?.preventDefault()
    this.clearSelection()
  }

  selectItemAtIndex(index) {
    const items = this.dropdown.querySelectorAll('li[data-index]')
    if (items[index]) {
      this.selectItem(items[index])
    }
  }
}
