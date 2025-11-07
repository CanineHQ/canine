import AsyncSearchDropdownController from "./components/async_search_dropdown_controller"

export default class extends AsyncSearchDropdownController {
  async fetchResults(query) {
    const response = await fetch(`/build_packs/search?q=${encodeURIComponent(query)}`)
    if (!response.ok) {
      throw new Error('Failed to fetch buildpacks')
    }
    const data = await response.json()
    return data
  }

  renderItem(buildpack) {
    const latest = buildpack.latest
    const verifiedBadge = latest.verified
      ? '<span class="badge badge-primary badge-sm">Verified</span>'
      : ''

    return `
      <div class="flex justify-between items-start text-left">
        <div class="flex flex-col flex-1">
          <div class="font-semibold">
            ${latest.namespace}/${latest.name}
          </div>
          <div class="text-sm text-base-content/60">${latest.description || 'No description'}</div>
          <div class="text-xs text-base-content/70 mt-1">
            Latest: ${latest.version} | ${latest.licenses?.join(', ') || 'No license info'}
          </div>
        </div>
        ${verifiedBadge}
      </div>
    `
  }

  onItemSelect(buildpack, itemElement) {
    const latest = buildpack.latest
    this.dispatch("buildpack-selected", {
      detail: {
        namespace: latest.namespace,
        name: latest.name,
        version: latest.version,
        description: latest.description
      }
    })
  }
}
