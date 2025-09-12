import { Controller } from "@hotwired/stimulus"
import { destroy, get } from '@rails/request.js'

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

  add(e) {
    e.preventDefault();
    this._add("", "", null, true)
  }

  _add(name, value, id=null, isNew=false) {
    const container = this.containerTarget;
    const div = document.createElement("div");
    const isHidden = !isNew && id !== null
    const displayValue = isHidden ? '' : value
    const placeholder = isHidden ? '••••••••••••••••••••••••' : 'VALUE'
    
    div.innerHTML = `
      <div class="flex items-center my-4 space-x-2" data-env-id="${id || ''}">
        <input aria-label="Env key" placeholder="KEY" class="input input-bordered focus:outline-offset-0" type="text" name="environment_variables[][name]" value="${name}">
        ${isHidden ? `<input type="hidden" name="environment_variables[][keep_existing_value]" value="true">` : ''}
        <input 
          aria-label="Env value" 
          placeholder="${placeholder}" 
          class="input input-bordered focus:outline-offset-0 w-full" 
          type="text" 
          name="environment_variables[][value]" 
          value="${displayValue}"
          ${isHidden ? 'readonly' : ''}
        >
        ${isHidden ? `
          <button 
            type="button" 
            class="btn btn-neutral"
            data-action="environment-variables#reveal"
          >
            Reveal
          </button>
        ` : ''}
        <button type="button" class="btn btn-danger" data-action="environment-variables#remove">Delete</button>
      </div>
    `;
    container.appendChild(div);
  }

  async reveal(event) {
    event.preventDefault();
    const button = event.target;
    const wrapper = button.closest('[data-env-id]');
    const envId = wrapper.dataset.envId;
    const input = wrapper.querySelector('input[name="environment_variables[][value]"]');
    const keepExistingInput = wrapper.querySelector('input[name="environment_variables[][keep_existing_value]"]');
    
    if (!envId) return;
    
    button.textContent = 'Loading...';
    button.disabled = true;
    
    try {
      const response = await get(`/projects/${this.projectIdValue}/environment_variables/${envId}`)
      if (response.ok) {
        const data = await response.json
        input.value = data.value
        input.readOnly = false
        input.placeholder = 'VALUE'
        // Remove the keep_existing_value hidden input since we now have the real value
        if (keepExistingInput) {
          keepExistingInput.remove()
        }
        button.remove()
      } else {
        button.textContent = 'Error'
        setTimeout(() => {
          button.textContent = 'Reveal'
          button.disabled = false
        }, 2000)
      }
    } catch (error) {
      console.error('Failed to reveal value:', error)
      button.textContent = 'Error'
      setTimeout(() => {
        button.textContent = 'Reveal'
        button.disabled = false
      }, 2000)
    }
  }

  async remove(event) {
    event.preventDefault();
    const div = event.target.closest("[data-env-id]");
    div.remove();
  }
}
