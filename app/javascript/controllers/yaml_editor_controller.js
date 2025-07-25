import { Controller } from "@hotwired/stimulus"
import { EditorView, basicSetup } from "codemirror"
import { EditorState } from "@codemirror/state"
import { yaml } from "@codemirror/lang-yaml"
import { oneDark } from "@codemirror/theme-one-dark"
import { indentWithTab } from "@codemirror/commands"
import { keymap } from "@codemirror/view"

export default class extends Controller {
  static targets = ["textarea", "editor"]

  connect() {
    this.setupEditor()
  }

  disconnect() {
    if (this.editorView) {
      this.editorView.destroy()
    }
  }

  setupEditor() {
    const initialContent = this.textareaTarget.value || ''
    
    // Create the editor state with YAML syntax highlighting and dark theme
    const state = EditorState.create({
      doc: initialContent,
      extensions: [
        basicSetup,
        yaml(),
        oneDark,
        keymap.of([indentWithTab]),
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

    // Create the editor view
    this.editorView = new EditorView({
      state,
      parent: this.editorTarget
    })

    // Hide the original textarea
    this.textareaTarget.style.display = 'none'
  }

  updateTextarea(content) {
    this.textareaTarget.value = content
    // Dispatch input event to ensure form validation works
    this.textareaTarget.dispatchEvent(new Event('input', { bubbles: true }))
  }
}
