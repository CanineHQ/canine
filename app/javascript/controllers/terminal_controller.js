import { Controller } from "@hotwired/stimulus"
import { Terminal } from "@xterm/xterm"
import { FitAddon } from "@xterm/addon-fit"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["container", "status", "dropOverlay", "statusMessage"]
  static values = { token: String, uploadUrl: String, podName: String, bracketPaste: Boolean }

  connect() {
    this.setupTerminal()
    this.connectChannel()
    if (this.hasUploadUrlValue) {
      this.setupDragAndDrop()
      this.setupPasteUpload()
    }
    this.resizeObserver = new ResizeObserver(() => this.onResize())
    this.resizeObserver.observe(this.containerTarget)
  }

  disconnect() {
    this.resizeObserver?.disconnect()
    this.channel?.unsubscribe()
    this.terminal?.dispose()
  }

  setupTerminal() {
    this.terminal = new Terminal({
      cursorBlink: true,
      fontSize: 14,
      fontFamily: "'JetBrains Mono', 'Fira Code', 'Cascadia Code', Menlo, monospace",
      theme: {
        background: "#1f2937",
        foreground: "#a9b1d6",
        cursor: "#c0caf5",
        selectionBackground: "#33467c",
        black: "#15161e",
        red: "#f7768e",
        green: "#9ece6a",
        yellow: "#e0af68",
        blue: "#7aa2f7",
        magenta: "#bb9af7",
        cyan: "#7dcfff",
        white: "#a9b1d6",
      },
    })

    this.fitAddon = new FitAddon()
    this.terminal.loadAddon(this.fitAddon)
    this.terminal.open(this.containerTarget)

    document.fonts.ready.then(() => {
      this.fitAddon.fit()
      this.sendResize()
    })

    this.terminal.attachCustomKeyEventHandler((event) => {
      if (event.key === "Tab") {
        return true
      }
      if (event.ctrlKey && event.type === "keydown") {
        const key = event.key.toLowerCase()
        if (key === "v") return false
        return true
      }
      return true
    })

    this.terminal.onData((data) => {
      this.channel?.send({ type: "input", data: data })
    })
  }

  connectChannel() {
    const consumer = createConsumer()

    this.channel = consumer.subscriptions.create(
      { channel: "PodShellChannel", token: this.tokenValue },
      {
        connected: () => {
          this.setStatus("Connected", "badge-success")
          this.terminal.focus()
          this.sendResize()
        },

        disconnected: () => {
          this.setStatus("Disconnected", "badge-error")
          this.terminal.writeln("\r\n\x1b[31mDisconnected from pod.\x1b[0m")
        },

        rejected: () => {
          this.setStatus("Rejected", "badge-error")
          this.terminal.writeln(
            "\r\n\x1b[31mConnection rejected. Token may be expired.\x1b[0m"
          )
        },

        received: (data) => {
          if (data.type === "output") {
            this.terminal.write(data.data)
          } else if (data.type === "error") {
            this.terminal.writeln(`\r\n\x1b[31m${data.data}\x1b[0m`)
          } else if (data.type === "exit") {
            this.setStatus("Exited", "badge-warning")
            this.terminal.writeln(
              "\r\n\x1b[33mShell session ended.\x1b[0m"
            )
          }
        },
      }
    )
  }

  onResize() {
    this.fitAddon?.fit()
    this.sendResize()
  }

  sendResize() {
    if (this.terminal && this.channel) {
      this.channel.send({
        type: "resize",
        cols: this.terminal.cols,
        rows: this.terminal.rows,
      })
    }
  }

  setStatus(text, badgeClass) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = text
      this.statusTarget.className = `badge badge-sm ${badgeClass}`
    }
  }

  setupDragAndDrop() {
    const el = this.element
    let dragCounter = 0

    el.addEventListener("dragenter", (e) => {
      e.preventDefault()
      dragCounter++
      if (dragCounter === 1) this.showDropOverlay()
    })

    el.addEventListener("dragleave", (e) => {
      e.preventDefault()
      dragCounter--
      if (dragCounter === 0) this.hideDropOverlay()
    })

    el.addEventListener("dragover", (e) => {
      e.preventDefault()
    })

    el.addEventListener("drop", (e) => {
      e.preventDefault()
      dragCounter = 0
      this.hideDropOverlay()
      const files = Array.from(e.dataTransfer.files)
      if (files.length > 0) this.uploadFiles(files)
    })
  }

  showDropOverlay() {
    if (this.hasDropOverlayTarget) {
      this.dropOverlayTarget.classList.remove("hidden")
    }
  }

  hideDropOverlay() {
    if (this.hasDropOverlayTarget) {
      this.dropOverlayTarget.classList.add("hidden")
    }
  }

  setupPasteUpload() {
    // xterm.js captures paste on its internal textarea — attach there
    const target = this.terminal.textarea || this.element
    target.addEventListener("paste", (e) => {
      const items = Array.from(e.clipboardData?.items || [])
      const imageItems = items.filter((item) => item.type.startsWith("image/"))
      if (imageItems.length === 0) return

      e.preventDefault()
      e.stopPropagation()
      const files = imageItems
        .map((item) => item.getAsFile())
        .filter(Boolean)
      if (files.length > 0) this.uploadFiles(files)
    })
  }

  showStatusMessage(text, type = "info") {
    if (!this.hasStatusMessageTarget) return

    const alertClass = {
      info: "alert-info",
      success: "alert-success",
      error: "alert-error",
    }[type]

    this.statusMessageTarget.innerHTML = `<div class="alert ${alertClass} text-sm py-2 px-3 shadow-lg">${text}</div>`
    this.statusMessageTarget.classList.remove("hidden")
  }

  hideStatusMessage() {
    if (!this.hasStatusMessageTarget) return
    this.statusMessageTarget.classList.add("hidden")
  }

  async uploadFiles(files) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    for (const file of files) {
      this.showStatusMessage(`Uploading ${file.name}...`, "info")

      const formData = new FormData()
      formData.append("file", file)
      formData.append("pod_name", this.podNameValue)

      try {
        const response = await fetch(this.uploadUrlValue, {
          method: "POST",
          headers: { "X-CSRF-Token": csrfToken },
          body: formData,
        })

        const result = await response.json()

        if (response.ok) {
          this.showStatusMessage(`Uploaded to ${result.path}`, "success")
          setTimeout(() => this.hideStatusMessage(), 3000)
          if (this.bracketPasteValue) {
            this.channel?.send({
              type: "input",
              data: `\x1b[200~${result.path}\x1b[201~`,
            })
          }
        } else {
          this.showStatusMessage(result.error, "error")
          setTimeout(() => this.hideStatusMessage(), 5000)
        }
      } catch (err) {
        this.showStatusMessage(`Upload failed: ${err.message}`, "error")
        setTimeout(() => this.hideStatusMessage(), 5000)
      }
    }
  }
}
