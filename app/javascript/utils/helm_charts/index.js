export function getLogoImageUrl(packageData) {
  const logoImageId = packageData.logo_image_id;
  return logoImageId ? `https://artifacthub.io/image/${logoImageId}` : "https://artifacthub.io/static/media/placeholder_pkg_helm.png";
}

export async function getDefaultValues(
  repositoryName,
  repositoryUrl,
  chartName,
) {
  const params = new URLSearchParams({
    repository_name: repositoryName,
    repository_url: repositoryUrl,
    chart_name: chartName
  });

  const url = `/add_ons/default_values?${params.toString()}`;
  const response = await fetch(url);
  const html = await response.text()
  return html;
}

export function helmChartHeader(packageData) {
  const logoImageUrl = getLogoImageUrl(packageData);
  return `
      <div class="flex items-center gap-4">
        <img src="${logoImageUrl}" alt="${packageData.name}" class="h-16 w-16">
        <div class="flex-1">
          <div class="flex items-center justify-between mb-1">
            <h2 class="text-xl font-semibold">${packageData.name}</h2>
            <div class="flex items-center gap-2">
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
          <p class="text-sm text-base-content/70 mb-2">${packageData.description}</p>
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

export function renderHelmChartCard(packageData) {
  // Create a temporary container to convert HTML string to DOM element
  const tempContainer = document.createElement('div');
  tempContainer.innerHTML = `
    <div class="mt-4 card bg-base-300 shadow-xl p-4">
      ${helmChartHeader(packageData)}
    </div>
  `;

  return tempContainer.firstElementChild;
}