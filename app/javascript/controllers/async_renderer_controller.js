import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame"]
  static values = {
    viewModel: String,
    params: String
  }

  connect() {
    this.render();
  }

  async render() {
    const params = JSON.parse(this.paramsValue)
    const queryString = new URLSearchParams(params).toString();
    const response = await fetch(`/async_render?view_model=${this.viewModelValue}&${queryString}`);

    if (response.ok) {
      const html = await response.text();
      this.frameTarget.innerHTML = html;
    } else {
      this.frameTarget.innerHTML = `<div class="text-error flex items-center gap-2"><iconify-icon icon="lucide:triangle-alert" width="24" height="24"></iconify-icon> Failed to load</div>`;
    }
  }
}
