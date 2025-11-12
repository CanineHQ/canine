import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["list", "template", "modal", "baseBuilder", "availableBuildpacks", "selectedBuildpacks"]
  static values = {
    packs: Object
  }

  connect() {
    this.selectedPacks = []
    this.initializeSortable()

    // Listen for buildpack selection from search
    this.element.addEventListener("buildpack-search:buildpack-selected", this.handleSearchSelection.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("buildpack-search:buildpack-selected", this.handleSearchSelection.bind(this))
  }

  handleSearchSelection(event) {
    const { namespace, name, version, description } = event.detail

    // Create a pack object with buildpack.webp as the default image
    const pack = {
      key: `${namespace}/${name}`,
      namespace: namespace,
      name: name,
      version: version || '',
      image: '/images/languages/buildpack.webp',
      description: description || '',
      reference_type: 'registry'
    }

    // Check if already selected
    if (!this.selectedPacks.some(p => p.key === pack.key)) {
      this.selectedPacks.push(pack)
      this.displayAvailableBuildpacks()
      this.renderSelectedBuildpacks()
    }
  }

  initializeSortable() {
    if (this.hasListTarget) {
      this.sortable = Sortable.create(this.listTarget, {
        animation: 150,
        handle: ".drag-handle",
        ghostClass: "opacity-50"
      })
    }
  }

  initializeModalSortable() {
    if (this.hasSelectedBuildpacksTarget && !this.modalSortable) {
      this.modalSortable = Sortable.create(this.selectedBuildpacksTarget, {
        animation: 150,
        ghostClass: "opacity-50",
        onEnd: () => {
          this.updateSelectedPacksOrder()
        }
      })
    }
  }

  updateSelectedPacksOrder() {
    // Get the current DOM order and update selectedPacks array
    const elements = this.selectedBuildpacksTarget.querySelectorAll('[data-key]')
    this.selectedPacks = Array.from(elements).map(el => {
      const key = el.dataset.key
      return { key, ...this.packsValue[key] }
    })
  }

  openModal() {
    // Repopulate selectedPacks from existing buildpacks in the form
    this.selectedPacks = this.getExistingBuildpacks()
    this.displayAvailableBuildpacks()
    this.renderSelectedBuildpacks()
    this.modalTarget.showModal()
    // Initialize sortable after modal is shown
    setTimeout(() => this.initializeModalSortable(), 100)
  }

  closeModal() {
    this.modalTarget.close()
  }

  getExistingBuildpacks() {
    const existingPacks = []
    const cards = this.listTarget.querySelectorAll('.card')

    cards.forEach(card => {
      const namespaceInput = card.querySelector('input[name*="[namespace]"]')
      const nameInput = card.querySelector('input[name*="[name]"]')

      if (namespaceInput && nameInput) {
        const key = `${namespaceInput.value}/${nameInput.value}`
        const pack = this.packsValue[key]
        if (pack) {
          existingPacks.push({ key, ...pack })
        }
      }
    })

    return existingPacks
  }

  displayAvailableBuildpacks() {
    const builder = this.baseBuilderTarget.value
    const namespace = this.detectNamespace(builder)

    if (!namespace) {
      this.availableBuildpacksTarget.innerHTML = '<div class="text-sm text-gray-500 p-4 text-center">Please select a base builder first</div>'
      return
    }

    const availablePacks = Object.entries(this.packsValue)
      .filter(([key, pack]) => pack.namespace === namespace)
      .map(([key, pack]) => ({ key, ...pack }))

    if (availablePacks.length === 0) {
      this.availableBuildpacksTarget.innerHTML = '<div class="text-sm text-gray-500 p-4 text-center">No buildpacks available for this builder</div>'
      return
    }

    this.renderAvailableBuildpacks(availablePacks)
  }

  renderAvailableBuildpacks(packs) {
    const filteredPacks = packs.filter(pack =>
      !this.selectedPacks.some(selected => selected.key === pack.key)
    )

    if (filteredPacks.length === 0) {
      this.availableBuildpacksTarget.innerHTML = '<div class="text-sm text-gray-500 p-4 text-center">All buildpacks selected</div>'
      return
    }

    const html = filteredPacks.map(pack => `
      <div class="p-3 hover:bg-base-200 cursor-pointer border-b border-base-300 flex items-center gap-3"
           data-action="click->buildpack-fields#selectBuildpack"
           data-key="${pack.key}">
        <img src="${pack.image}" alt="${pack.key}" class="w-10 h-10 object-contain" />
        <div class="flex-1">
          <div class="font-medium">${pack.namespace}/${pack.name}</div>
          <div class="text-sm text-gray-600">${pack.description}</div>
        </div>
      </div>
    `).join('')

    this.availableBuildpacksTarget.innerHTML = html
  }

  renderSelectedBuildpacks() {
    if (this.selectedPacks.length === 0) {
      this.selectedBuildpacksTarget.innerHTML = '<div class="text-sm text-gray-500 p-4 text-center">No buildpacks selected</div>'
      if (this.modalSortable) {
        this.modalSortable.destroy()
        this.modalSortable = null
      }
      return
    }

    const html = this.selectedPacks.map((pack, index) => `
      <div class="p-3 hover:bg-base-200 cursor-move border-b border-base-300 flex items-center gap-3"
           data-key="${pack.key}"
           data-index="${index}">
        <img src="${pack.image}" alt="${pack.key}" class="w-10 h-10 object-contain" />
        <div class="flex-1">
          <div class="font-medium">${pack.namespace}/${pack.name}</div>
          <div class="text-sm text-gray-600">${pack.description}</div>
        </div>
        <button type="button" class="btn btn-xs btn-circle btn-ghost" data-action="click->buildpack-fields#deselectBuildpack" data-index="${index}">
          <iconify-icon icon="mdi:close" width="16" height="16"></iconify-icon>
        </button>
      </div>
    `).join('')

    this.selectedBuildpacksTarget.innerHTML = html

    // Reinitialize sortable after rendering
    if (this.modalSortable) {
      this.modalSortable.destroy()
      this.modalSortable = null
    }
    this.initializeModalSortable()
  }

  detectNamespace(builder) {
    if (!builder) return null

    if (builder.includes("paketo")) {
      return "paketo-buildpacks"
    } else if (builder.includes("heroku")) {
      return "heroku"
    }
    return null
  }

  selectBuildpack(event) {
    const key = event.currentTarget.dataset.key
    const pack = { key, ...this.packsValue[key] }

    this.selectedPacks.push(pack)
    this.displayAvailableBuildpacks()
    this.renderSelectedBuildpacks()
  }

  deselectBuildpack(event) {
    event.stopPropagation()
    const index = parseInt(event.currentTarget.dataset.index)
    this.selectedPacks.splice(index, 1)
    this.displayAvailableBuildpacks()
    this.renderSelectedBuildpacks()
  }

  addSelectedBuildpacks() {
    // Clear existing buildpacks from the list
    this.listTarget.innerHTML = ''

    this.selectedPacks.forEach((pack, index) => {
      const template = this.templateTarget.content || this.templateTarget
      const clone = template.cloneNode(true)

      const img = clone.querySelector('[data-template-image]')
      img.src = pack.image
      img.alt = pack.key

      const title = clone.querySelector('[data-template-title]')
      title.textContent = `${pack.namespace}/${pack.name}`

      const description = clone.querySelector('[data-template-description]')
      description.textContent = pack.description

      const namespaceInput = clone.querySelector('[data-template-namespace]')
      namespaceInput.value = pack.namespace

      const nameInput = clone.querySelector('[data-template-name]')
      nameInput.value = pack.name

      const referenceTypeInput = clone.querySelector('[data-template-reference-type]')
      referenceTypeInput.value = pack.reference_type

      const container = document.createElement('div')
      container.appendChild(clone)

      this.listTarget.insertAdjacentHTML("beforeend", container.innerHTML)
    })

    this.closeModal()
  }

  remove(event) {
    event.target.closest(".card").remove()
  }
}
