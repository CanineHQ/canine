import { Controller } from "@hotwired/stimulus"
import { Terminal } from "@xterm/xterm"
import { FitAddon } from "@xterm/addon-fit"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["container", "status"]
  static values = { token: String }

  connect() {
    this.setupTerminal()
    this.connectChannel()
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
}
