// Customizable command palette for advanced users
// Opens with cmd+k or ctrl+k by default
// https://github.com/excid3/ninja-keys

import { Controller } from "@hotwired/stimulus"
import { destroy } from '@rails/request.js'

export default class extends Controller {
  static targets = ["container"]
  static values = {
    vars: String,
    projectId: String,
  }

  connect() {
    const vars = JSON.parse(this.varsValue)
    vars.forEach(v => {
      this._add(v.name, v.value, v.id)
    })
  }

  download() {
    const vars = JSON.parse(this.varsValue)
    const env = vars.map(v => `${v.name}=${v.value}`).join("\n")
    const blob = new Blob([env], { type: "text/plain" })
    const url = URL.createObjectURL(blob)
    const a = document.createElement("a")
    a.href = url
    a.download = ".env"
    a.click()
  }

  add(e) {
    e.preventDefault();
    this._add("", "")
  }

  _add(name, value, id=null) {
    const container = this.containerTarget;
    const div = document.createElement("div");
    // Make the value 3x the width of the name
    div.innerHTML = `
      <div class="flex items-center my-4 space-x-2" id="${id ? id : ''}">
        <input aria-label="Env key" placeholder="KEY" class="input input-bordered focus:outline-offset-0" type="text" name="environment_variables[][name]" value="${name}">
        <input aria-label="Env value" placeholder="VALUE" class="input input-bordered focus:outline-offset-0 w-full" type="text" name="environment_variables[][value]" value="${value}">
        <button type="button" class="btn btn-danger" data-action="environment-variables#remove">Delete</button>
      </div>
    `;
    container.appendChild(div);
  }

  async remove(event) {
    event.preventDefault();
    const div = event.target.closest("div");
    div.remove();
  }
}
