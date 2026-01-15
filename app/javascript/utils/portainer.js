export class PortainerChecker {
  static STATUS_OK = "ok";
  static STATUS_UNAUTHORIZED = "unauthorized";
  static STATUS_ERROR = "error";

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]').content
  }

  toResult(response) {
    if (response.status === 401) {
      return PortainerChecker.STATUS_UNAUTHORIZED;
    }

    if (response.status === 502) {
      return PortainerChecker.STATUS_ERROR;
    }

    if (response.ok) {
      return PortainerChecker.STATUS_OK;
    }

    return PortainerChecker.STATUS_ERROR;
  }

  async checkReachable(url) {
    const response = await fetch('/stack_manager/check_reachable', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': this.csrfToken()
      },
      body: JSON.stringify({ stack_manager: { url } })
    })
    return this.toResult(response);
  }

  async verifyConnectivity() {
    const response = await fetch('/stack_manager/verify_connectivity', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': this.csrfToken()
      }
    })
    return this.toResult(response);
  }

  async verifyPortainerUrl(url, accessToken) {
    const response = await fetch('/stack_manager/verify_url', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': this.csrfToken()
      },
      body: JSON.stringify({ stack_manager: { url, access_token: accessToken } })
    })

    return this.toResult(response);
  }
}
