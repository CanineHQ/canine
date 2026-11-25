import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["dialog", "query", "item", "empty"];

  open() {
    this.queryTarget.value = "";
    this.filter();
    this.dialogTarget.showModal();
    this.queryTarget.focus();
  }

  filter() {
    const query = this.queryTarget.value.trim().toLowerCase();
    let visible = 0;
    this.itemTargets.forEach((item) => {
      const match = item.dataset.name.toLowerCase().includes(query);
      item.hidden = !match;
      if (match) visible++;
    });
    this.emptyTarget.hidden = visible > 0;
  }

  newOrganization() {
    this.dialogTarget.close();
    document.getElementById("click_outside_modal_2").showModal();
  }
}
