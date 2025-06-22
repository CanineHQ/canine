import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["provider", "gitProviderLabel", "gitRepository", "githubConnectButton"];
  static values = { providers: String }

  connect() {
    this.setLabels();
  }

  setLabels() {
    const provider = JSON.parse(this.providersValue).find(provider => provider.id === parseInt(this.providerTarget.value))
    if (!provider) {
      this.gitRepositoryTarget.classList.add("hidden");
      return;
    }
    this.gitRepositoryTarget.classList.remove("hidden");
    if (provider.provider === "github") {
      this.githubConnectButtonTarget.classList.remove("hidden");
      this.gitProviderLabelTargets.forEach(label => label.textContent = "Github");
    } else if (provider.provider === "gitlab") {
      this.githubConnectButtonTarget.classList.add("hidden");
      this.gitProviderLabelTargets.forEach(label => label.textContent = "Gitlab");
    }
  }

  selectProvider(event) {
    event.preventDefault()
    this.setLabels();
  }
}
