import { Controller } from "@hotwired/stimulus"
import { EditorView, basicSetup } from "codemirror"
import { EditorState } from "@codemirror/state"
import { yaml } from "@codemirror/lang-yaml"
import { oneDark } from "@codemirror/theme-one-dark"

export default class extends Controller {
  static targets = ["file", "content", "filename", "editor"]

  connect() {
    this.setupEditor()
  }

  disconnect() {
    if (this.editorView) {
      this.editorView.destroy()
    }
  }

  setupEditor() {
    const initialContent = this.contentTarget.value || ''

    // Create the editor state with YAML syntax highlighting, dark theme, and read-only
    const state = EditorState.create({
      doc: initialContent,
      extensions: [
        basicSetup,
        yaml(),
        oneDark,
        EditorState.readOnly.of(true),
        EditorView.theme({
          "&": {
            fontSize: "14px",
            border: "1px solid #374151",
            borderRadius: "0.5rem",
            height: "450px"
          },
          ".cm-content": {
            padding: "12px"
          },
          ".cm-scroller": {
            fontFamily: "'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace",
            overflow: "auto"
          }
        })
      ]
    })

    // Create the editor view
    this.editorView = new EditorView({
      state,
      parent: this.editorTarget
    })

    // Hide the original textarea
    this.contentTarget.style.display = 'none'
  }

  selectFile(event) {
    const fileButton = event.currentTarget
    const manifestKey = fileButton.dataset.manifestKey

    // Update active state
    this.fileTargets.forEach(file => {
      file.classList.remove("active")
    })
    fileButton.classList.add("active")

    // Update content display
    const content = fileButton.dataset.manifestContent

    // Update CodeMirror editor
    if (this.editorView) {
      this.editorView.dispatch({
        changes: {
          from: 0,
          to: this.editorView.state.doc.length,
          insert: content
        }
      })
    }

    // Update filename display
    this.filenameTarget.textContent = manifestKey
  }
}
