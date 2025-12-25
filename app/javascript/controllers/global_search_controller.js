import { Controller } from "@hotwired/stimulus"
import { debounce } from "../utils"

export default class extends Controller {
  static targets = ["input", "results", "modal"]

  connect() {
    this.searchHandler = debounce(this.performSearch.bind(this), 300)
    document.addEventListener('keydown', this.handleKeydown.bind(this))
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleKeydown.bind(this))
  }

  handleKeydown(e) {
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
      e.preventDefault()
      this.toggle()
      return
    }

    if (!this.modalTarget.open) return

    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault()
      this.handleArrowNavigation(e.key === 'ArrowDown')
    } else if (e.key === 'Enter') {
      e.preventDefault()
      const activeLink = this.resultsTarget.querySelector('a.active')
      if (activeLink) {
        window.location.href = activeLink.href
      }
    }
  }

  toggle() {
    if (this.modalTarget.open) {
      this.modalTarget.close()
    } else {
      this.open()
    }
  }

  open() {
    this.inputTarget.value = ""
    this.performSearch()
    this.modalTarget.showModal()
    this.inputTarget.focus()
  }

  search() {
    this.searchHandler()
  }

  async performSearch() {
    const query = this.inputTarget.value.trim()

    if (query) {
      this.resultsTarget.innerHTML = this.loadingState()
    }

    const response = await fetch(`/search?q=${encodeURIComponent(query)}`, {
      headers: { 'Accept': 'text/vnd.turbo-stream.html' }
    })

    if (response.ok) {
      const html = await response.text()
      Turbo.renderStreamMessage(html)
      this.selectFirstLink()
    }
  }

  loadingState() {
    return `<div class="p-4 text-center flex items-center justify-center gap-2">
      <span class="loading loading-spinner loading-sm"></span>
      <span>Searching...</span>
    </div>`
  }

  selectFirstLink() {
    requestAnimationFrame(() => {
      const links = this.resultsTarget.querySelectorAll('a')
      links.forEach(link => link.classList.remove('active'))
      if (links.length > 0) {
        links[0].classList.add('active')
      }
    })
  }

  handleArrowNavigation(isDown) {
    const links = Array.from(this.resultsTarget.querySelectorAll('a'))
    if (!links.length) return

    const currentIndex = links.findIndex(link => link.classList.contains('active'))
    links.forEach(link => link.classList.remove('active'))

    let newIndex
    if (currentIndex === -1) {
      newIndex = isDown ? 0 : links.length - 1
    } else {
      newIndex = isDown
        ? (currentIndex + 1) % links.length
        : (currentIndex - 1 + links.length) % links.length
    }

    links[newIndex].classList.add('active')
    links[newIndex].scrollIntoView({ behavior: 'smooth', block: 'nearest' })
  }
}
