import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"

// A reusable file tree browser that shows a modal with expandable directories.
// Configure with data-file-browser-mode-value="file" or "directory" to control
// what can be selected. Connects to the repo-details controller for provider/repo/branch context.
export default class extends Controller {
  static targets = ["hiddenInput", "displayValue", "modal", "tree", "loading", "fallbackInput"]
  static values = {
    mode: { type: String, default: "file" }, // "file" or "directory"
    fileTreeUrl: { type: String, default: "/integrations/git/repo_details/file_tree" },
    filterPattern: { type: String, default: "" }, // regex pattern to highlight matching files (e.g. "Dockerfile")
    defaultValue: { type: String, default: "" },
    providerSelectId: { type: String, default: "provider_select" },
    repositoryInputId: { type: String, default: "project_repository_url" },
    branchSelectId: { type: String, default: "" }
  }

  connect() {
    this.treeData = null
    this.expandedDirs = new Set([""])
  }

  get repoDetailsController() {
    const wrapper = this.element.closest("[data-controller~='repo-details']")
    return wrapper ? this.application.getControllerForElementAndIdentifier(wrapper, "repo-details") : null
  }

  get providerId() {
    // Use parent repo-details controller's value if available
    const ctrl = this.repoDetailsController
    const selectId = ctrl ? ctrl.providerSelectIdValue : this.providerSelectIdValue
    const el = document.getElementById(selectId)
    return el ? el.value : ""
  }

  get repositoryUrl() {
    const ctrl = this.repoDetailsController
    const inputId = ctrl ? ctrl.repositoryInputIdValue : this.repositoryInputIdValue
    const el = document.getElementById(inputId)
    return el ? el.value : ""
  }

  get branch() {
    const branchInput = this.element.closest("[data-controller~='repo-details']")
      ?.querySelector("[data-repo-details-target='branchHidden']")
    return branchInput ? branchInput.value : ""
  }

  async openModal() {
    this.modalTarget.showModal()
    await this.loadTree()
  }

  closeModal() {
    this.modalTarget.close()
  }

  async loadTree() {
    const providerId = this.providerId
    const repositoryUrl = this.repositoryUrl
    const branch = this.branch

    if (!providerId || !repositoryUrl || !branch) {
      this.treeTarget.innerHTML = '<p class="text-base-content/60 text-sm p-4">Select a repository and branch first.</p>'
      return
    }

    this.loadingTarget.classList.remove("hidden")
    this.treeTarget.classList.add("hidden")

    try {
      const response = await get(
        `${this.fileTreeUrlValue}?provider_id=${providerId}&repository_url=${encodeURIComponent(repositoryUrl)}&branch=${encodeURIComponent(branch)}`,
        { responseKind: "json" }
      )

      if (response.ok) {
        const data = await response.json
        this.treeData = this.buildTreeStructure(data.entries)
        this.renderTree()
      } else {
        this.treeTarget.innerHTML = '<p class="text-error text-sm p-4">Failed to load file tree.</p>'
      }
    } catch {
      this.treeTarget.innerHTML = '<p class="text-error text-sm p-4">Failed to load file tree.</p>'
    }

    this.loadingTarget.classList.add("hidden")
    this.treeTarget.classList.remove("hidden")
  }

  // Build nested tree from flat path list
  buildTreeStructure(entries) {
    const root = { name: ".", path: "", type: "directory", children: [] }
    const dirMap = { "": root }

    // Sort: directories first, then alphabetical
    entries.sort((a, b) => {
      if (a.type !== b.type) return a.type === "directory" ? -1 : 1
      return a.path.localeCompare(b.path)
    })

    entries.forEach(entry => {
      const parts = entry.path.split("/")
      const name = parts[parts.length - 1]
      const parentPath = parts.slice(0, -1).join("/")

      // Ensure parent directory exists
      if (!dirMap[parentPath]) {
        this.ensureDir(dirMap, parentPath, root)
      }

      const node = { name, path: entry.path, type: entry.type, children: [] }
      dirMap[parentPath].children.push(node)

      if (entry.type === "directory") {
        dirMap[entry.path] = node
      }
    })

    return root
  }

  ensureDir(dirMap, path, root) {
    if (dirMap[path]) return
    const parts = path.split("/")
    const parentPath = parts.slice(0, -1).join("/")
    if (!dirMap[parentPath]) {
      this.ensureDir(dirMap, parentPath, root)
    }
    const node = { name: parts[parts.length - 1], path, type: "directory", children: [] }
    dirMap[parentPath].children.push(node)
    dirMap[path] = node
  }

  renderTree() {
    const currentValue = this.hiddenInputTarget.value
    this.treeTarget.innerHTML = ""

    // Root selector for directory mode
    if (this.modeValue === "directory") {
      this.treeTarget.appendChild(this.createRootRow(currentValue))
    }

    this.renderChildren(this.treeData.children, this.treeTarget, 0, currentValue)
  }

  createRootRow(currentValue) {
    const row = document.createElement("div")
    const isSelected = currentValue === "./" || currentValue === "." || !currentValue
    row.className = `flex items-center gap-2 px-3 py-1.5 cursor-pointer rounded hover:bg-base-200 ${isSelected ? "bg-primary/10 font-semibold" : ""}`
    row.innerHTML = `
      <span class="w-4 text-xs text-base-content/60 flex-shrink-0">&#x2212;</span>
      <svg class="w-4 h-4 text-primary flex-shrink-0" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/><line x1="9" y1="14" x2="15" y2="14"/></svg>
      <span class="flex-1 text-sm">./ (root)</span>
    `
    row.addEventListener("click", () => this.selectEntry("./", "directory"))
    return row
  }

  renderChildren(children, container, depth, currentValue) {
    // Sort: directories first within each level, then alpha
    const sorted = [...children].sort((a, b) => {
      if (a.type !== b.type) return a.type === "directory" ? -1 : 1
      return a.name.localeCompare(b.name)
    })

    sorted.forEach(node => {
      const row = document.createElement("div")
      const isDir = node.type === "directory"
      const isExpanded = this.expandedDirs.has(node.path)
      const fullPath = isDir ? `./${node.path}` : `./${node.path}`

      const isSelectable = isDir ? this.modeValue === "directory" : this.modeValue === "file"
      const isSelected = currentValue === fullPath
      const isHighlighted = this.filterPatternValue && new RegExp(this.filterPatternValue, "i").test(node.name)

      let bgClass = ""
      if (isSelected) bgClass = "bg-primary/10 font-semibold"
      else if (isSelectable) bgClass = "hover:bg-base-200"

      row.className = `flex items-center gap-2 px-3 py-1.5 rounded ${bgClass} ${isSelectable ? "cursor-pointer" : "opacity-40"}`
      row.style.paddingLeft = `${(depth + 1) * 16 + 12}px`

      if (isDir) {
        const toggleIcon = isExpanded ? "&#x2212;" : "&#x2b;"
        const folderIcon = isExpanded
          ? '<svg class="w-4 h-4 text-primary flex-shrink-0" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/><line x1="9" y1="14" x2="15" y2="14"/></svg>'
          : '<svg class="w-4 h-4 text-primary flex-shrink-0" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>'
        row.innerHTML = `
          <span class="w-4 text-xs text-base-content/60 flex-shrink-0 cursor-pointer" data-dir-toggle>${toggleIcon}</span>
          ${folderIcon}
          <span class="flex-1 text-sm truncate">${this.escapeHtml(node.name)}</span>
        `

        // Toggle on chevron click
        row.querySelector("[data-dir-toggle]").addEventListener("click", (e) => {
          e.stopPropagation()
          this.toggleDir(node.path)
        })

        if (isSelectable) {
          row.addEventListener("click", () => this.selectEntry(fullPath, "directory"))
        } else {
          row.classList.add("cursor-pointer")
          row.classList.remove("opacity-40")
          row.addEventListener("click", () => this.toggleDir(node.path))
        }
      } else {
        row.innerHTML = `
          <span class="w-4 flex-shrink-0"></span>
          <svg class="w-4 h-4 flex-shrink-0 ${isHighlighted ? "text-accent" : "text-base-content/40"}" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
          <span class="flex-1 text-sm truncate ${isHighlighted ? "text-accent font-medium" : ""}">${this.escapeHtml(node.name)}</span>
        `

        if (isSelectable) {
          row.addEventListener("click", () => this.selectEntry(fullPath, "file"))
        }
      }

      container.appendChild(row)

      // Render children if expanded
      if (isDir && isExpanded && node.children.length > 0) {
        this.renderChildren(node.children, container, depth + 1, currentValue)
      }
    })
  }

  toggleDir(path) {
    if (this.expandedDirs.has(path)) {
      this.expandedDirs.delete(path)
    } else {
      this.expandedDirs.add(path)
    }
    this.renderTree()
  }

  selectEntry(path, type) {
    this.hiddenInputTarget.value = path
    this.displayValueTarget.textContent = path
    this.closeModal()
  }

  // Called externally (by repo-details) when branch changes to clear cached tree
  resetTree() {
    this.treeData = null
    this.expandedDirs = new Set([""])
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
