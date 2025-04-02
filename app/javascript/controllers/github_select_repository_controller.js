import { get } from "@rails/request.js";
import { Controller } from "@hotwired/stimulus"
import { debounce } from "../utils";

export default class extends Controller {
  static targets = ["repository", "button", "publicRepository", "modal", "repositories", "repositoriesList"]

  connect() {
    this.page = 1
    this.repositoriesListTarget.addEventListener("scroll", this.onScroll.bind(this)) // Added scroll event listener
    this.searchFunc = debounce(async (e) => {
      const searchTerm = e.target.value.toLowerCase()
      await get(`/integrations/github/repositories?q=${searchTerm}`, {
        responseKind: "turbo-stream"
      })
    }, 500)
  }

  async filterRepositories(e) {
    e.preventDefault();
    this.searchFunc(e);
  }

  closeModal() {
    this.buttonTarget.removeAttribute("disabled")
    this.modalTarget.removeAttribute("open")
  }

  selectPublicRepository() {
    this.repositoryTarget.value = this.publicRepositoryTarget.value
    this.closeModal()
  }

  selectRepository(e) {
    this.repositoryTarget.value = e.target.dataset.repositoryName;
    this.closeModal()
  }

  connectToGithub(e) {
    // Set attribute of src to the url of the frame
    this.modalTarget.setAttribute("open", "true")
    
    // Disable the button after clicking
    this.buttonTarget.setAttribute("disabled", "true")
    this.fetchMoreRepositories();
  }

  async onScroll(event) {
    const target = event.target;
    if (target.scrollTop + target.clientHeight >= target.scrollHeight) {
      await this.fetchMoreRepositories();
    }
  }

  async fetchMoreRepositories() {
    await get(`/integrations/github/repositories?page=${this.page}`, {
      responseKind: "turbo-stream"
    })
    this.page += 1;
  }
}
