import { Controller } from "@hotwired/stimulus"

// Drives an agent computer's computer server over its WebSocket API (proxied at /agent_computers/:id/api/ws).
// The server answers each {command, params} message in order, so replies are matched to a FIFO of pending requests.
export default class extends Controller {
  static targets = ["status", "screen", "placeholder", "log", "text", "shell", "shellOutput", "clickMode", "autoRefresh"]
  static values = { url: String }

  connect() {
    this.pending = []
    this.screenSize = null
    this.open().then(() => this.refresh())
  }

  disconnect() {
    clearInterval(this.refreshTimer)
    this.socket?.close()
  }

  open() {
    if (this.socket?.readyState === WebSocket.OPEN) return Promise.resolve()
    if (this.opening) return this.opening

    const scheme = window.location.protocol === "https:" ? "wss" : "ws"
    this.socket = new WebSocket(`${scheme}://${window.location.host}${this.urlValue}/ws`)
    this.setStatus("Connecting...", "badge-warning")

    this.opening = new Promise((resolve, reject) => {
      this.socket.onopen = () => {
        this.opening = null
        this.setStatus("Connected", "badge-success")
        resolve()
      }
      this.socket.onerror = () => {
        this.opening = null
        reject(new Error("WebSocket error"))
      }
    })
    this.socket.onmessage = (event) => this.pending.shift()?.resolve(JSON.parse(event.data))
    this.socket.onclose = () => {
      // The proxy drops idle connections; the next command reconnects
      this.setStatus("Disconnected", "badge-ghost")
      this.pending.splice(0).forEach(({ reject }) => reject(new Error("Connection closed")))
    }
    return this.opening
  }

  async send(command, params = {}, { log = true } = {}) {
    await this.open()
    const startedAt = performance.now()
    const response = await new Promise((resolve, reject) => {
      this.pending.push({ resolve, reject })
      this.socket.send(JSON.stringify({ command, params }))
    })
    if (log) this.appendLog(command, params, response, Math.round(performance.now() - startedAt))
    return response
  }

  // --- Screen ---

  async refresh() {
    const response = await this.send("screenshot", { format: "jpeg", quality: 70 }, { log: false })
    if (!response.success) return this.appendLog("screenshot", {}, response, 0)

    this.screenTarget.src = `data:image/jpeg;base64,${response.image_data}`
    this.screenTarget.hidden = false
    this.placeholderTarget.hidden = true
    if (!this.screenSize) {
      const size = await this.send("get_screen_size", {}, { log: false })
      this.screenSize = size.size
    }
  }

  toggleAutoRefresh() {
    clearInterval(this.refreshTimer)
    if (this.autoRefreshTarget.checked) this.refreshTimer = setInterval(() => this.refresh(), 2000)
  }

  // Map a click on the scaled screenshot back to desktop coordinates
  async clickScreen(event) {
    event.preventDefault()
    if (!this.screenSize) return

    const rect = this.screenTarget.getBoundingClientRect()
    const x = Math.round((event.clientX - rect.left) * this.screenSize.width / rect.width)
    const y = Math.round((event.clientY - rect.top) * this.screenSize.height / rect.height)
    const command = event.type === "contextmenu" ? "right_click" : this.clickModeTarget.value

    await this.send(command, { x, y })
    setTimeout(() => this.refresh(), 400)
  }

  // --- Keyboard ---

  async typeText(event) {
    event.preventDefault()
    const text = this.textTarget.value
    if (!text) return

    await this.send("type_text", { text })
    this.textTarget.value = ""
    setTimeout(() => this.refresh(), 300)
  }

  async pressKey(event) {
    await this.send("press_key", { key: event.params.key })
    setTimeout(() => this.refresh(), 300)
  }

  async hotkey(event) {
    await this.send("hotkey", { keys: event.params.keys.split("+") })
    setTimeout(() => this.refresh(), 300)
  }

  async scroll(event) {
    await this.send(event.params.direction === "up" ? "scroll_up" : "scroll_down", { clicks: 3 })
    setTimeout(() => this.refresh(), 300)
  }

  // --- Shell ---

  // stdin must be closed too, or the launched app holds computer-server's pipe open and run_command never returns
  async launch(event) {
    await this.send("run_command", { command: `setsid ${event.params.app} </dev/null >/dev/null 2>&1 &` })
    setTimeout(() => this.refresh(), 1500)
  }

  async runShell(event) {
    event.preventDefault()
    const command = this.shellTarget.value
    if (!command) return

    this.shellOutputTarget.textContent = "Running..."
    const response = await this.send("run_command", { command })
    const output = [response.stdout, response.stderr].filter(Boolean).join("\n")
    this.shellOutputTarget.textContent = response.success
      ? `${output || "(no output)"}\n[exit ${response.return_code}]`
      : `Error: ${response.error}`
  }

  // --- UI ---

  setStatus(text, badgeClass) {
    this.statusTarget.textContent = text
    this.statusTarget.className = `badge badge-sm ${badgeClass}`
  }

  appendLog(command, params, response, ms) {
    const summary = { ...response }
    if (summary.image_data) summary.image_data = `<${summary.image_data.length} base64 chars>`

    const entry = document.createElement("div")
    entry.className = "border-b border-base-300 py-1"
    const ok = response.success ? "text-success" : "text-error"
    entry.innerHTML = `<div><span class="${ok}">●</span> <span class="font-semibold"></span> <span class="text-base-content/50"></span></div><div class="text-base-content/70 break-all"></div>`
    entry.querySelector(".font-semibold").textContent = `${command}(${JSON.stringify(params)})`
    entry.querySelector(".text-base-content\\/50").textContent = `${ms}ms`
    entry.querySelector(".break-all").textContent = JSON.stringify(summary)
    this.logTarget.prepend(entry)
  }
}
