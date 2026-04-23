import { Controller } from "@hotwired/stimulus"
import { get } from '@rails/request.js'

export default class extends Controller {
  static targets = ["container"]
  static values = {
    vars: String,
    projectId: String,
  }

  connect() {
    const vars = JSON.parse(this.varsValue)
    vars.forEach(v => {
      this._add(v.name, v.value, v.id, false, v.storage_type || 'config')
    })
  }

  add(e) {
    e.preventDefault();
    this._add("", "", null, true, 'config')
  }

  _add(name, value, id=null, isNew=false, storageType='config') {
    const container = this.containerTarget;
    const div = document.createElement("div");
    const isHidden = !isNew && id !== null
    const placeholder = isHidden ? '••••••••••••••••••••••••' : 'VALUE'
    const isSecret = storageType === 'secret'
    const lockIcon = isSecret ? 'lucide:lock' : 'lucide:lock-open'
    const lockColor = isSecret ? 'text-warning' : 'text-base-content'

    div.innerHTML = `
      <div class="flex items-start my-4 space-x-2" data-env-id="${id || ''}" data-storage-type="${storageType}">
        ${id ? `<input type="hidden" name="environment_variables[][id]" value="${id}">` : ''}
        <input aria-label="Env key" placeholder="KEY" class="input input-bordered focus:outline-offset-0" type="text" name="environment_variables[][name]" value="${name}">
        ${isHidden ? `<input type="hidden" name="environment_variables[][keep_existing_value]" value="true">` : ''}
        <input type="hidden" name="environment_variables[][storage_type]" value="${storageType}">
        <textarea
          aria-label="Env value"
          placeholder="${placeholder}"
          class="textarea textarea-bordered focus:outline-offset-0 w-full font-mono resize-none text-base overflow-x-auto"
          name="environment_variables[][value]"
          rows="1"
          wrap="off"
          data-controller="textarea-autogrow"
          data-textarea-autogrow-resize-debounce-delay-value="100"
          ${isHidden ? 'readonly' : ''}
        ></textarea>
        ${isHidden ? `
          <button
            type="button"
            class="btn btn-square btn-ghost"
            data-action="environment-variables#reveal"
            title="Reveal value"
          >
            <iconify-icon icon="lucide:eye" height="20"></iconify-icon>
          </button>
        ` : ''}
        <button
          type="button"
          class="btn btn-square btn-ghost ${lockColor}"
          data-action="environment-variables#toggleStorageType"
          title="${isSecret ? 'Secret (stored in Kubernetes Secrets)' : 'Config (stored in ConfigMap)'}"
        >
          <iconify-icon icon="${lockIcon}" height="20"></iconify-icon>
        </button>
        <button type="button" class="btn btn-danger" data-action="environment-variables#remove">Delete</button>
      </div>
    `;

    // Set textarea value programmatically to avoid HTML injection issues
    if (!isHidden) {
      const textarea = div.querySelector('textarea[name="environment_variables[][value]"]');
      textarea.value = value;
    }

    container.appendChild(div);
  }

  async reveal(event) {
    event.preventDefault();
    const button = event.currentTarget;
    const wrapper = button.closest('[data-env-id]');
    const envId = wrapper.dataset.envId;
    const input = wrapper.querySelector('textarea[name="environment_variables[][value]"]');
    const keepExistingInput = wrapper.querySelector('input[name="environment_variables[][keep_existing_value]"]');
    
    if (!envId) return;
    
    button.querySelector('iconify-icon').setAttribute('icon', 'lucide:loader')
    button.disabled = true;
    
    try {
      const response = await get(`/projects/${this.projectIdValue}/environment_variables/${envId}`)
      if (response.ok) {
        const data = await response.json
        input.value = data.value
        input.readOnly = false
        input.placeholder = 'VALUE'
        input.dispatchEvent(new Event('input'))
        // Remove the keep_existing_value hidden input since we now have the real value
        if (keepExistingInput) {
          keepExistingInput.remove()
        }
        // Swap to hide button
        const icon = button.querySelector('iconify-icon')
        icon.setAttribute('icon', 'lucide:eye-off')
        button.setAttribute('title', 'Hide value')
        button.dataset.action = 'environment-variables#hide'
        button.disabled = false
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

  hide(event) {
    event.preventDefault();
    const button = event.currentTarget;
    const wrapper = button.closest('[data-env-id]');
    const input = wrapper.querySelector('textarea[name="environment_variables[][value]"]');

    // Clear value and restore masked state
    input.value = ''
    input.readOnly = true
    input.placeholder = '••••••••••••••••••••••••'
    input.dispatchEvent(new Event('input'))

    // Re-add keep_existing_value hidden input
    const keepInput = document.createElement('input')
    keepInput.type = 'hidden'
    keepInput.name = 'environment_variables[][keep_existing_value]'
    keepInput.value = 'true'
    wrapper.querySelector('input[name="environment_variables[][name]"]').after(keepInput)

    // Swap back to reveal button
    const icon = button.querySelector('iconify-icon')
    icon.setAttribute('icon', 'lucide:eye')
    button.setAttribute('title', 'Reveal value')
    button.dataset.action = 'environment-variables#reveal'
  }

  toggleStorageType(event) {
    event.preventDefault();
    const button = event.currentTarget;
    const wrapper = button.closest('[data-env-id]');
    const currentType = wrapper.dataset.storageType;
    const newType = currentType === 'secret' ? 'config' : 'secret';

    // Update data attribute
    wrapper.dataset.storageType = newType;

    // Update hidden input
    const hiddenInput = wrapper.querySelector('input[name="environment_variables[][storage_type]"]');
    if (hiddenInput) {
      hiddenInput.value = newType;
    }

    // Update button icon and color
    const icon = button.querySelector('iconify-icon');
    const isSecret = newType === 'secret';
    icon.setAttribute('icon', isSecret ? 'lucide:lock' : 'lucide:lock-open');

    // Update button color classes
    button.classList.remove('text-warning', 'text-base-content');
    button.classList.add(isSecret ? 'text-warning' : 'text-base-content');

    // Update title
    button.setAttribute('title', isSecret ? 'Secret (stored in Kubernetes Secrets)' : 'Config (stored in ConfigMap)');
  }

  async remove(event) {
    event.preventDefault();
    const div = event.target.closest("[data-env-id]");
    div.remove();
  }
}
