import { Controller } from "@hotwired/stimulus"
import { PortainerChecker } from "../../utils/portainer"

const AUTHENTICATION_VERIFICATION_METHOD = "authentication";
const URL_VERIFICATION_METHOD = "url";

export default class extends Controller {
  static targets = [ "message", "verifyUrlSuccess", "verifyUrlError", "verifyUrlLoading", "verifyUrlNotAllowed" ]

  static values = {
    verificationMethod: String,
    verifyUrl: String,
  }

  async connect() {
    this.verifyUrlLoadingTarget.classList.remove('hidden')
    const portainerChecker = new PortainerChecker();
    let result = null;
    if (this.verificationMethodValue === AUTHENTICATION_VERIFICATION_METHOD) {
      result = await portainerChecker.verifyPortainerAuthentication();
    } else if (this.verificationMethodValue === URL_VERIFICATION_METHOD) {
      const url = this.verifyUrlValue;
      result = await portainerChecker.checkReachable(url);
    }

    if (result === PortainerChecker.STATUS_UNAUTHORIZED) {
      this.logout();
    } else if (result === PortainerChecker.STATUS_OK) {
      this.verifyUrlSuccessTarget.classList.remove('hidden')
    } else if (result === PortainerChecker.STATUS_NOT_ALLOWED) {
      this.verifyUrlNotAllowedTarget.classList.remove('hidden')
    } else {
      this.verifyUrlErrorTarget.classList.remove('hidden')
    }
    this.verifyUrlLoadingTarget.classList.add('hidden')
  }

  async logout() {
    try {
      const response = await fetch('/users/sign_out', {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        credentials: 'same-origin'
      })

      if (response.ok) {
        const data = await response.json()
        window.location.href = data.redirect_url
      } else {
        window.location.href = '/users/sign_in'
      }
    } catch (error) {
      window.location.href = '/users/sign_in'
    }
  }
}
