export function getLogoImageUrl(packageData) {
  const logoImageId = packageData.logo_image_id;
  return logoImageId ? `https://artifacthub.io/image/${logoImageId}` : "https://artifacthub.io/static/media/placeholder_pkg_helm.png";
}

function helmChartContent(packageData, widthClass = "") {
  const logoImageUrl = getLogoImageUrl(packageData);
  return `
      <div class="flex items-center gap-4 ${widthClass}">
        <img src="${logoImageUrl}" alt="${packageData.name}" class="h-16 w-16 shrink-0">
        <div class="flex-1 min-w-0">
          <div class="flex items-center justify-between mb-1 gap-2">
            <h2 class="text-xl font-semibold truncate">${packageData.name}</h2>
            <div class="flex items-center gap-2 shrink-0">
              <span class="text-sm text-base-content/70">v${packageData.version}</span>
              ${packageData.repository.verified_publisher ?
                '<span class="badge badge-success badge-sm">Verified Publisher</span>' : ''}
            </div>
          </div>
          <div class="flex gap-2 mb-2">
            ${packageData.stars > 0 ?
              `<span class="px-2 py-1 bg-base-300 rounded text-xs flex items-center gap-1">
                <iconify-icon icon="lucide:star" ></iconify-icon>
                ${packageData.stars}
              </span>` : ''}
          </div>
          <p class="text-sm text-base-content/70 mb-2 line-clamp-2">${packageData.description}</p>
          <div class="flex gap-4 text-xs text-base-content/70">
            <div class="flex items-center gap-1">
              <iconify-icon icon="lucide:globe"></iconify-icon>
              <a href="${packageData.repository.url}" class="hover:underline">${packageData.repository.url}</a>
            </div>
            <div class="flex items-center gap-1">
              <iconify-icon icon="lucide:building"></iconify-icon>
              <span>${packageData.repository.organization_display_name}</span>
            </div>
          </div>
        </div>
      </div>
  `
}

// For dropdown items - constrained width
export function helmChartHeader(packageData) {
  return helmChartContent(packageData, "max-w-lg lg:max-w-xl xl:max-w-2xl")
}

// For selected card - full width with close button
export function renderHelmChartCard(packageData) {
  const logoImageUrl = getLogoImageUrl(packageData);
  const tempContainer = document.createElement('div');
  tempContainer.innerHTML = `
    <div class="mt-4 card bg-base-300 shadow-xl" data-helm-chart-card>
      <div class="card-body p-4">
        <div class="flex items-start gap-4">
          <img src="${logoImageUrl}" alt="${packageData.name}" class="h-12 w-12 shrink-0">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2">
              <h2 class="text-lg font-semibold">${packageData.name}</h2>
              <span class="text-sm text-base-content/70">v${packageData.version}</span>
              ${packageData.repository.verified_publisher ?
                '<span class="badge badge-success badge-sm">Verified Publisher</span>' : ''}
              ${packageData.stars > 0 ?
                `<span class="text-xs text-base-content/70 flex items-center gap-1">
                  <iconify-icon icon="lucide:star"></iconify-icon>
                  ${packageData.stars}
                </span>` : ''}
            </div>
            <p class="text-sm text-base-content/70 mt-1">${packageData.description}</p>
          </div>
          <button type="button" class="btn btn-ghost btn-sm btn-square shrink-0" data-action="helm-search#clearSelection">
            <iconify-icon icon="lucide:x" class="text-lg"></iconify-icon>
          </button>
        </div>
        <div class="flex gap-4 text-xs text-base-content/50 mt-2">
          <a href="${packageData.repository.url}" class="hover:underline flex items-center gap-1">
            <iconify-icon icon="lucide:globe"></iconify-icon>
            ${packageData.repository.url}
          </a>
          <span class="flex items-center gap-1">
            <iconify-icon icon="lucide:building"></iconify-icon>
            ${packageData.repository.organization_display_name}
          </span>
        </div>
      </div>
    </div>
  `;

  return tempContainer.firstElementChild;
}