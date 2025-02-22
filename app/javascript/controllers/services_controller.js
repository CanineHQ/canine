import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["internalUrl"]

  copyToClick(event) {
    navigator.clipboard.writeText(this.internalUrlTarget.textContent);
    const element = event.currentTarget;
    element.classList.add('animate-click');
    setTimeout(() => element.classList.remove('animate-click'), 300);
  }

  showTelepresenceGuide(event) {
    event.preventDefault();
    this.internalUrlTarget.setAttribute("href", event.target.dataset.internalUrl);
    this.internalUrlTarget.querySelector("code").textContent = event.target.dataset.internalUrl;
    telepresence_guide.showModal();
  }
}