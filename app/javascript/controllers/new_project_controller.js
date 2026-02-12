import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["provider", "gitProviderLabel", "gitRepository", "githubConnectButton", "gitlabConnectButton", "repositoryUrl"];
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

    // Show/hide connect buttons based on provider type
    this.githubConnectButtonTarget.classList.toggle("hidden", provider.provider !== "github");
    this.gitlabConnectButtonTarget.classList.toggle("hidden", provider.provider !== "gitlab");

    // Set provider label
    const labels = { github: "Github", gitlab: "Gitlab", bitbucket: "Bitbucket" };
    this.gitProviderLabelTargets.forEach(label => label.textContent = labels[provider.provider] || provider.provider);
  }

  selectProvider(event) {
    event.preventDefault()
    this.repositoryUrlTarget.value = "";
    this.setLabels();
  }
}
