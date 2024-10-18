import Apex from "../apex";
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    dataset: Array,
  }

  connect() {
    new Apex(this.element, this.datasetValue).render();
  }
}
