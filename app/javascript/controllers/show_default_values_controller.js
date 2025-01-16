import { Controller } from "@hotwired/stimulus"
import { getDefaultValues } from "../utils/helm_charts"

export default class extends Controller {
  static targets = [ "modal", "content" ]
  static values = {
    repositoryName: String,
    repositoryUrl: String,
    chartName: String
  }
  connect() {
  }

  async show(event) {
    event.preventDefault()
    const html = await getDefaultValues(this.repositoryNameValue, this.repositoryUrlValue, this.chartNameValue)
    this.contentTarget.innerHTML = html
    // Show the modal on the page already
    this.modalTarget.showModal()
  }
}
