// Customizable command palette for advanced users
// Opens with cmd+k or ctrl+k by default
// https://github.com/excid3/ninja-keys

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]
  static values = {
    vars: String
  }

  connect() {
    const vars = JSON.parse(this.varsValue)
    vars.forEach(v => {
      console.log(v)
      this._add(v.name, v.value)
    })
  }

  add(e) {
    e.preventDefault();
    this._add("", "")
  }

  _add(name, value) {
    const container = this.containerTarget;
    const div = document.createElement("div");
    // Make the value 3x the width of the name
    div.innerHTML = `
      <div class="flex items-center my-4 space-x-2">
        <input type="text" name="environment_variables[][name]" class="form-control w-1/3" value="${name}" />
        <input type="text" name="environment_variables[][value]" class="form-control w-2/3" value="${value}" />
        <button type="button" class="btn btn-danger" data-action="environment-variables#remove">Delete</button>
      </div>
    `;
    container.appendChild(div);
  }

  remove(e) {
    e.preventDefault();
    const div = e.target.closest("div");
    div.remove();
  }
}
