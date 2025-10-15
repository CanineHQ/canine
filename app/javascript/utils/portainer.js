export class PortainerChecker {
  static STATUS_OK = "ok";
  static STATUS_UNAUTHORIZED = "unauthorized";
  static STATUS_NOT_ALLOWED = "not_allowed";
  static STATUS_ERROR = "error";

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]').content
  }

  async verifyPortainerAuthentication() {
    const response = await fetch('/stack_manager/verify_login', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken()
      }
    })

    return this.toResult(response);
  }

  toResult(response) {
    if (response.status === 401) {
      return PortainerChecker.STATUS_UNAUTHORIZED;
    }

    if (response.status === 405) {
      return PortainerChecker.STATUS_NOT_ALLOWED;
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
        'X-CSRF-Token': this.csrfToken()
      },
      body: JSON.stringify({ stack_manager: { url } })
    })
    return this.toResult(response);
  }

  async verifyPortainerUrl(url, accessCode) {
    const response = await fetch('/stack_manager/verify_url', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken()
      },
      body: JSON.stringify({ stack_manager: { url, access_code: accessCode } })
    })

    return this.toResult(response);
  }
}