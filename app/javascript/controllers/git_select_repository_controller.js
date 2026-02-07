import { get } from "@rails/request.js";
import { Controller } from "@hotwired/stimulus"
import { debounce } from "../utils";

export default class extends Controller {
  static targets = ["button", "publicRepository", "modal", "repositories", "repositoriesList", "username"]
  static values = { endpoint: String, repositoryId: String, providerSelectId: String }

  connect() {
    this.page = 1
    this.repositoriesListTarget.addEventListener("scroll", this.onScroll.bind(this))
    this.searchFunc = debounce(async (e) => {
      const searchTerm = e.target.value.toLowerCase()
      await get(`${this.endpointValue}?q=${searchTerm}&provider_id=${this.selectedProviderId}`, {
        responseKind: "turbo-stream"
      })
    }, 500)
  }

  get repositoryInput() {
    return document.getElementById(this.repositoryIdValue)
  }

  get selectedProviderId() {
    const select = document.getElementById(this.providerSelectIdValue)
    return select ? select.value : ''
  }

  async filterRepositories(e) {
    e.preventDefault();
    this.showLoading();
    this.searchFunc(e);
  }

  showLoading() {
    this.repositoriesListTarget.innerHTML = `
      <div class="flex justify-center items-center h-full">
        <div class='loading loading-spinner loading-sm'></div>
      </div>
    `;
  }

  closeModal() {
    this.buttonTarget.removeAttribute("disabled")
    this.modalTarget.removeAttribute("open")
  }

  selectPublicRepository() {
    this.repositoryInput.value = this.publicRepositoryTarget.value
    this.closeModal()
  }

  selectRepository(e) {
    this.repositoryInput.value = e.target.dataset.repositoryName;
    this.closeModal()
  }

  openModal(e) {
    this.modalTarget.setAttribute("open", "true")
    this.buttonTarget.setAttribute("disabled", "true")
    this.page = 1
    this.fetchMoreRepositories();
  }

  async onScroll(event) {
    const target = event.target;
    if (target.scrollTop + target.clientHeight >= target.scrollHeight) {
      await this.fetchMoreRepositories();
    }
  }

  async fetchMoreRepositories() {
    await get(`${this.endpointValue}?page=${this.page}&provider_id=${this.selectedProviderId}`, {
      responseKind: "turbo-stream"
    })
    this.page += 1;
  }
}
