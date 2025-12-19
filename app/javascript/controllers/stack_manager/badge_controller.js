import { Controller } from "@hotwired/stimulus"
import { PortainerChecker } from "../../utils/portainer"

export default class extends Controller {
  static targets = [ "verifyUrlSuccess", "verifyUrlError", "verifyUrlLoading", "verifyUrlUnauthorized" ]

  static values = {
    verifyUrl: String,
    credentialsPath: { type: String, default: "/providers" },
    rbacEnabled: { type: Boolean, default: false }
  }

  async connect() {
    this.verifyUrlLoadingTarget.classList.remove('hidden')
    const portainerChecker = new PortainerChecker();

    // Only verify user connectivity if RBAC is enabled, otherwise just check URL reachability
    const result = this.rbacEnabledValue
      ? await portainerChecker.verifyConnectivity()
      : await portainerChecker.checkReachable(this.verifyUrlValue);

    if (result === PortainerChecker.STATUS_OK) {
      this.verifyUrlSuccessTarget.classList.remove('hidden')
    } else if (result === PortainerChecker.STATUS_UNAUTHORIZED && this.rbacEnabledValue) {
      if (this.hasVerifyUrlUnauthorizedTarget) {
        this.verifyUrlUnauthorizedTarget.classList.remove('hidden')
      } else {
        this.verifyUrlErrorTarget.classList.remove('hidden')
      }
    } else {
      this.verifyUrlErrorTarget.classList.remove('hidden')
    }
    this.verifyUrlLoadingTarget.classList.add('hidden')
  }

  navigateToCredentials() {
    window.location.href = this.credentialsPathValue
  }
}
