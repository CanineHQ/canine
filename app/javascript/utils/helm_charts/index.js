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
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"/>
              </svg>
              <a href="${packageData.repository.url}" class="hover:underline">${packageData.repository.url}</a>
            </div>
            <div class="flex items-center gap-1">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/>
              </svg>
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