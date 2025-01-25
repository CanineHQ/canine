import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame", "repository", "button", "publicRepository", "modal", "repositories"]

  connect() {
    this.frameTarget.addEventListener("turbo:frame-load", this.onFrameLoad.bind(this))
  }

  filterRepositories(e) {
    const searchTerm = e.target.value.toLowerCase()
    // Hide repositories that don't contain the search term
    this.repositoriesTargets.forEach(repo => {
      if (!repo.textContent.toLowerCase().includes(searchTerm)) {
        repo.classList.add("hidden")
      } else {
        repo.classList.remove("hidden")
      }
    })
  }

  selectPublicRepository() {
    this.repositoryTarget.value = this.publicRepositoryTarget.value

    // Close the modal
    this.modalTarget.removeAttribute("open")
  }

  onFrameLoad(event) {
    this.buttonTarget.removeAttribute("disabled")
  }

  selectRepository(e) {
    this.repositoryTarget.value = e.target.dataset.repositoryName;
    this.modalTarget.removeAttribute("open")
  }

  connectToGithub(e) {
    // Set attribute of src to the url of the frame
    console.log(this.frameTarget)
    this.frameTarget.setAttribute("src", "/integrations/github/repositories")
    
    // Disable the button after clicking
    this.buttonTarget.setAttribute("disabled", "true")
  }
}
