import { Controller } from "@hotwired/stimulus"
import { EditorView, basicSetup } from "codemirror"
import { EditorState } from "@codemirror/state"
import { yaml } from "@codemirror/lang-yaml"
import { oneDark } from "@codemirror/theme-one-dark"

export default class extends Controller {
  static targets = ["modal", "editor", "button", "chartUrl", "version", "spinner"]
  static values = {
    metadataUrl: String,
    chartUrl: String,
    chartUrlInputId: String,
    version: String // Helm chart version
  }

  disconnect() {
    if (this.editorView) {
      this.editorView.destroy()
    }
  }

  // version is only null for new add-ons, in which case it fetches the latest
  async showDefaultYaml() {
    const chartUrl = this.getChartUrl()
    if (!chartUrl || !this.hasMetadataUrlValue) return

    this.spinnerTarget.classList.remove('hidden')
    this.buttonTarget.disabled = true

    try {
      const url = new URL(this.metadataUrlValue, window.location.origin)
      url.searchParams.set('chart_url', chartUrl)
      if (this.hasVersionValue && this.versionValue) {
        url.searchParams.set('version', this.versionValue)
      }

      const response = await fetch(url, {
        headers: { 'Accept': 'application/json' }
      })

      if (response.ok) {
        const data = await response.json()
        if (data.default_values) {
          this.chartUrlTarget.textContent = chartUrl
          this.versionTarget.textContent = data.version ? `v${data.version}` : ''
          this.setupEditor(data.default_values)
          this.modalTarget.showModal()
        }
      }
    } catch (error) {
      console.error('Failed to fetch default YAML:', error)
    } finally {
      this.spinnerTarget.classList.add('hidden')
      this.buttonTarget.disabled = false
    }
  }

  setupEditor(content) {
    if (this.editorView) {
      this.editorView.destroy()
    }

    const state = EditorState.create({
      doc: content,
      extensions: [
        basicSetup,
        yaml(),
        oneDark,
        EditorState.readOnly.of(true),
        EditorView.editable.of(false),
        EditorView.theme({
          "&": {
            fontSize: "14px",
            border: "1px solid #374151",
            borderRadius: "0.5rem"
          },
          ".cm-content": {
            padding: "12px"
          },
          ".cm-scroller": {
            fontFamily: "'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace"
          }
        })
      ]
    })

    this.editorView = new EditorView({
      state,
      parent: this.editorTarget
    })
  }

  getChartUrl() {
    if (this.hasChartUrlValue && this.chartUrlValue) {
      return this.chartUrlValue
    }
    if (this.hasChartUrlInputIdValue) {
      const input = document.getElementById(this.chartUrlInputIdValue)
      return input?.value
    }
    return null
  }

  closeModal() {
    this.modalTarget.close()
  }
}
