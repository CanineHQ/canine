import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"
import { debounce } from "../utils"

export default class extends Controller {
  static targets = ["branchHidden", "branchDisplay", "branchDropdown", "branchList", "branchSearch", "branchLoading", "branchWrapper", "branchError"]
  static values = {
    branchesUrl: { type: String, default: "/integrations/git/repo_details/branches" },
    providerSelectId: { type: String, default: "provider_select" },
    repositoryInputId: { type: String, default: "project_repository_url" }
  }

  connect() {
    this.dropdownOpen = false
    this.debouncedSearch = debounce((query) => this.fetchBranches(query), 300)

    this.outsideClickHandler = (e) => {
      if (this.hasBranchDropdownTarget && !this.branchDropdownTarget.contains(e.target)) {
        this.closeDropdown()
      }
    }
    document.addEventListener("click", this.outsideClickHandler)

    if (this.providerId && this.repositoryUrl) {
      this.loadBranches()
    }
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClickHandler)
  }

  get providerId() {
    const el = document.getElementById(this.providerSelectIdValue)
    return el ? el.value : ""
  }

  get repositoryUrl() {
    const el = document.getElementById(this.repositoryInputIdValue)
    return el ? el.value : ""
  }

  get baseParams() {
    return `provider_id=${this.providerId}&repository_url=${encodeURIComponent(this.repositoryUrl)}`
  }

  async loadBranches() {
    const providerId = this.providerId
    const repositoryUrl = this.repositoryUrl
    if (!providerId || !repositoryUrl) return

    this.branchLoadingTarget.classList.remove("hidden")
    this.branchDropdownTarget.classList.add("hidden")
    this.hideBranchError()

    try {
      const response = await get(
        `${this.branchesUrlValue}?${this.baseParams}`,
        { responseKind: "json" }
      )

      if (response.ok) {
        const data = await response.json
        if (!data.branches || data.branches.length === 0) {
          this.showBranchError("No branches found. Check that the repository URL is correct.")
        } else {
          const currentValue = this.branchHiddenTarget.value
          const selected = currentValue || data.default_branch || data.branches[0] || ""
          this.selectBranch(selected)
          this.renderBranchList(data.branches)
          this.branchDropdownTarget.classList.remove("hidden")
        }
      } else {
        const data = await response.json.catch(() => ({}))
        const message = data.error || "Could not access this repository. Check the URL and credentials."
        this.showBranchError(message)
      }
    } catch {
      this.showBranchError("Could not connect to the Git provider. Please try again.")
    }

    this.branchLoadingTarget.classList.add("hidden")
    this.branchWrapperTarget.classList.remove("hidden")
  }

  toggleDropdown(e) {
    e.stopPropagation()
    if (this.dropdownOpen) {
      this.closeDropdown()
    } else {
      this.openDropdown()
    }
  }

  openDropdown() {
    this.dropdownOpen = true
    this.branchListTarget.classList.remove("hidden")
    this.branchSearchTarget.value = ""
    this.branchSearchTarget.classList.remove("hidden")
    this.branchSearchTarget.focus()
    this.fetchBranches("")
  }

  closeDropdown() {
    this.dropdownOpen = false
    this.branchListTarget.classList.add("hidden")
    this.branchSearchTarget.classList.add("hidden")
  }

  searchBranches(e) {
    this.debouncedSearch(e.target.value)
  }

  async fetchBranches(query) {
    const providerId = this.providerId
    const repositoryUrl = this.repositoryUrl
    if (!providerId || !repositoryUrl) return

    const qParam = query ? `&q=${encodeURIComponent(query)}` : ""

    this.branchListTarget.innerHTML = `
      <div class="flex justify-center items-center py-4">
        <span class="loading loading-spinner loading-sm"></span>
      </div>
    `

    try {
      const response = await get(
        `${this.branchesUrlValue}?${this.baseParams}${qParam}`,
        { responseKind: "json" }
      )

      if (response.ok) {
        const data = await response.json
        this.renderBranchList(data.branches || [])
      } else {
        this.branchListTarget.innerHTML = '<div class="px-3 py-2 text-sm text-error">Failed to load branches</div>'
      }
    } catch {
      this.branchListTarget.innerHTML = '<div class="px-3 py-2 text-sm text-error">Failed to load branches</div>'
    }
  }

  renderBranchList(branches) {
    this.branchListTarget.innerHTML = ""

    if (branches.length === 0) {
      const empty = document.createElement("div")
      empty.className = "px-3 py-2 text-sm text-base-content/50"
      empty.textContent = "No branches found"
      this.branchListTarget.appendChild(empty)
      return
    }

    branches.forEach(branch => {
      const item = document.createElement("div")
      const isSelected = branch === this.branchHiddenTarget.value
      item.className = `px-3 py-1.5 text-sm cursor-pointer truncate hover:bg-base-200 rounded ${isSelected ? "bg-primary/10 font-semibold" : ""}`
      item.textContent = branch
      item.addEventListener("click", (e) => {
        e.stopPropagation()
        this.selectBranch(branch)
        this.closeDropdown()
      })
      this.branchListTarget.appendChild(item)
    })
  }

  selectBranch(branch) {
    this.branchHiddenTarget.value = branch
    this.branchDisplayTarget.textContent = branch || "Select a branch..."
    this.resetFileBrowsers()
  }

  resetFileBrowsers() {
    this.element.querySelectorAll("[data-controller~='file-browser']").forEach(el => {
      const controller = this.application.getControllerForElementAndIdentifier(el, "file-browser")
      if (controller) controller.resetTree()
    })
  }

  showBranchError(message) {
    if (!this.hasBranchErrorTarget) return
    this.branchErrorTarget.querySelector("span").textContent = message
    this.branchErrorTarget.classList.remove("hidden")
    this.branchDropdownTarget.classList.add("hidden")
    this.branchHiddenTarget.value = ""
    this.branchDisplayTarget.textContent = "Select a branch..."
  }

  hideBranchError() {
    if (!this.hasBranchErrorTarget) return
    this.branchErrorTarget.classList.add("hidden")
  }
}
