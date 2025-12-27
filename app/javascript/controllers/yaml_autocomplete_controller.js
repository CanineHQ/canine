import YamlEditorController from "./yaml_editor_controller"
import { EditorView, basicSetup } from "codemirror"
import { EditorState } from "@codemirror/state"
import { yaml } from "@codemirror/lang-yaml"
import { oneDark } from "@codemirror/theme-one-dark"
import { indentWithTab } from "@codemirror/commands"
import { keymap } from "@codemirror/view"
import { autocompletion, completionKeymap } from "@codemirror/autocomplete"

export default class extends YamlEditorController {
  static targets = ["textarea", "editor", "status"]
  static values = {
    metadataUrl: String, // URL to fetch schema from
    chartUrl: String, // Helm chart URL
    chartUrlInputId: String,
    version: String // Helm chart version
  }

  connect() {
    super.connect()
    if (this.hasChartUrlValue) {
      this.fetchSchema(this.chartUrlValue, this.versionValue)
    } else if (this.hasChartUrlInputIdValue) {
      this.chartUrlInput = document.getElementById(this.chartUrlInputIdValue)
      this.chartUrlInput.addEventListener('change', (e) => {
        this.fetchSchema(e.target.value)
      })
    }
  }

  // version is only null for new add-ons, in which case it fetches the latest
  async fetchSchema(chartUrl, version = null) {
    if (!this.hasMetadataUrlValue || !chartUrl) return

    this.updateStatus(chartUrl, 'loading')

    try {
      const url = new URL(this.metadataUrlValue, window.location.origin)
      url.searchParams.set('chart_url', chartUrl)
      if (version) {
        url.searchParams.set('version', version)
      }

      const response = await fetch(url, {
        headers: { 'Accept': 'application/json' }
      })

      if (response.ok) {
        const data = await response.json()
        this.schema = data.schema || {}
        this.updateStatus(chartUrl, 'success', data.version)
      } else {
        this.updateStatus(chartUrl, 'error')
      }
    } catch (error) {
      console.error('Failed to fetch schema:', error)
      this.updateStatus(chartUrl, 'error')
    }
  }

  setupEditor() {
    const initialContent = this.textareaTarget.value || ''

    const state = EditorState.create({
      doc: initialContent,
      extensions: [
        basicSetup,
        yaml(),
        oneDark,
        keymap.of([indentWithTab, ...completionKeymap]),
        autocompletion({
          override: [this.yamlCompletions.bind(this)]
        }),
        EditorView.theme({
          "&": {
            fontSize: "14px",
            border: "1px solid #374151",
            borderRadius: "0.5rem"
          },
          "&.cm-focused": {
            outline: "2px solid #3b82f6",
            outlineOffset: "-1px"
          },
          ".cm-content": {
            padding: "12px",
            minHeight: "250px"
          },
          ".cm-scroller": {
            fontFamily: "'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace"
          }
        }),
        EditorView.updateListener.of((update) => {
          if (update.docChanged) {
            this.updateTextarea(update.state.doc.toString())
          }
        })
      ]
    })

    this.editorView = new EditorView({
      state,
      parent: this.editorTarget
    })

    this.textareaTarget.style.display = 'none'
  }

  yamlCompletions(context) {
    const word = context.matchBefore(/[\w.]*/)
    if (!word || (word.from === word.to && !context.explicit)) {
      return null
    }

    const schema = this.schema ? this.schema : {}
    const { path, isValue, currentKey } = this.getCurrentPath(context)
    const schemaAtPath = this.getSchemaAtPath(schema, path)

    let options
    if (isValue && currentKey) {
      const propertySchema = schemaAtPath.properties?.[currentKey] || {}
      options = this.getValueCompletionOptions(propertySchema)
    } else {
      options = this.getCompletionOptions(schemaAtPath)
    }

    return {
      from: word.from,
      options: options
    }
  }

  getCurrentPath(context) {
    const doc = context.state.doc.toString()
    const pos = context.pos
    const lines = doc.slice(0, pos).split('\n')

    const path = []
    const indentStack = [{ indent: -1, key: null }]

    for (const line of lines) {
      const match = line.match(/^(\s*)(\w+)/)
      if (match) {
        const indent = match[1].length
        const key = match[2]

        // Pop stack until we find a parent with less indentation
        while (indentStack.length > 1 && indentStack[indentStack.length - 1].indent >= indent) {
          indentStack.pop()
        }

        indentStack.push({ indent, key })
      }
    }

    // Build path from stack (skip the root)
    for (let i = 1; i < indentStack.length; i++) {
      if (indentStack[i].key) {
        path.push(indentStack[i].key)
      }
    }

    // Check if we're typing a value (after a colon) or a key
    const currentLine = lines[lines.length - 1]
    const valueMatch = currentLine.match(/^(\s*)(\w+):\s*(\S*)$/)

    if (valueMatch) {
      // We're after a colon, typing a value
      const currentKey = valueMatch[2]
      // Remove the current key from path since we're typing its value
      if (path.length > 0 && path[path.length - 1] === currentKey) {
        path.pop()
      }
      return { path, isValue: true, currentKey }
    }

    // We're typing a key
    if (currentLine.match(/^\s*\w*$/) && path.length > 0) {
      path.pop()
    }

    return { path, isValue: false, currentKey: null }
  }

  getSchemaAtPath(schema, path) {
    let current = schema

    for (const key of path) {
      if (current.type === "object" && current.properties?.[key]) {
        current = current.properties[key]
      } else if (current.type === "array" && current.items) {
        current = current.items
      } else {
        return {}
      }
    }

    return current
  }

  getCompletionOptions(schema) {
    const options = []

    if (schema.properties) {
      for (const [key, value] of Object.entries(schema.properties)) {
        options.push({
          label: key,
          type: "property",
          detail: value.type || "",
          info: value.description || ""
        })
      }
    }

    return options
  }

  getValueCompletionOptions(schema) {
    const options = []

    if (schema.enum) {
      for (const value of schema.enum) {
        options.push({
          label: String(value),
          type: "enum",
          detail: "enum value"
        })
      }
    } else if (schema.type === "boolean") {
      options.push({ label: "true", type: "keyword", detail: "boolean" })
      options.push({ label: "false", type: "keyword", detail: "boolean" })
    }

    return options
  }

  updateStatus(chartUrl, status, version = null) {
    if (!this.hasStatusTarget) return

    this.statusTarget.classList.remove('text-red-400', 'text-green-400', 'text-yellow-400')

    const versionSuffix = version ? ` (v${version})` : ''

    if (status === 'loading') {
      this.statusTarget.textContent = `Loading schema: ${chartUrl}`
      this.statusTarget.classList.add('text-yellow-400')
    } else if (status === 'success') {
      this.statusTarget.textContent = `Schema: ${chartUrl}${versionSuffix}`
      this.statusTarget.classList.add('text-green-400')
    } else {
      this.statusTarget.textContent = `Failed to load schema: ${chartUrl}`
      this.statusTarget.classList.add('text-red-400')
    }
  }
}
