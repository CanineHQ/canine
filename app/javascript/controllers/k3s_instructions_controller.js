import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "next", "ipAddress", "ipAddressMessage", "installCommand"]

  connect() {
    this.step = 0;
  }

  complete() {
    this.nextTarget.type = "submit";
    this.nextTarget.innerHTML = "Submit";
  }

  async checkIpAddress() {
    const response = await fetch(`/clusters/check_k3s_ip_address`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ ip_address: this.ipAddressTarget.value })
    })
    const data = await response.json()
    return data.success
  }

  setLoading(loading) {
    this.nextTarget.disabled = loading;
    this.nextTarget.innerHTML = loading ? "Loading..." : "Next";
  }

  async setInstallCommand() {
    const command = `curl -sfL https://get.k3s.io | sh -s - --disable traefik --tls-san ${this.ipAddressTarget.value}`;
    this.installCommandTarget.innerHTML = command;
    this.installCommandTarget.dataset.clipboardText = command;
  }

  async updateStep(event) {

    const val = this.stepTargets[this.step].dataset.validation;
    if (val === "ip-address") {
      this.setInstallCommand();
    } else if (val === "validate-ip-address") {
      this.setLoading(true);
      const ipAddressWorking = await this.checkIpAddress()
      this.setLoading(false);
      if (!ipAddressWorking) {
        this.ipAddressTarget.classList.add("input-error")
        this.ipAddressMessageTarget.classList.add("error")
        this.ipAddressMessageTarget.innerHTML = "IP address is not reachable. Please check that K3s is installed and running on the server, and allow port 6443 through any firewalls."
        return
      } else {
        this.ipAddressTarget.classList.remove("error")
        this.ipAddressMessageTarget.classList.remove("error")
        this.ipAddressMessageTarget.classList.add("success")
        this.ipAddressMessageTarget.innerHTML = "IP address is reachable ✓"
        this.ipAddressTarget.classList.add("input-success")
        this.ipAddressTarget.classList.remove("input-error")
      }
    }

    this.step += 1;
    this.stepTargets.forEach(step => {
      step.classList.add("hidden")
    })
    // Show all steps up to the current step
    for (let i = 0; i <= this.step; i++) {
      this.stepTargets[i].classList.remove("hidden")
    }
    if (this.step === this.stepTargets.length - 1) {
      this.complete()
      event.preventDefault();
    }
  }

  update(event) {
    // Validate it is a valid IP address
    if (!/^(\d{1,3}\.){3}\d{1,3}$/.test(event.target.value)) {
      return
    }
    this.instructionsTarget.classList.remove("hidden")
  }
}

