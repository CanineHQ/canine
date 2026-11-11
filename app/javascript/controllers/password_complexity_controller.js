import { Controller } from "@hotwired/stimulus"

const RULES = [
  { test: v => v.length >= 8, label: "At least 8 characters" },
  { test: v => /[A-Z]/.test(v), label: "One uppercase letter" },
  { test: v => /[a-z]/.test(v), label: "One lowercase letter" },
  { test: v => /\d/.test(v), label: "One digit" },
  { test: v => /[^A-Za-z0-9]/.test(v), label: "One special character" },
]

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.checklist = document.createElement("ul")
    this.checklist.className = "text-sm mt-2 space-y-1 hidden"

    this.items = RULES.map(rule => {
      const li = document.createElement("li")
      li.className = "flex items-center gap-1.5 text-base-content/50"
      li.innerHTML = `<iconify-icon icon="lucide:circle" width="14"></iconify-icon> ${rule.label}`
      this.checklist.appendChild(li)
      return { li, rule }
    })

    this.inputTarget.parentNode.appendChild(this.checklist)
  }

  validate() {
    const value = this.inputTarget.value

    if (value.length === 0) {
      this.checklist.classList.add("hidden")
      return
    }

    this.checklist.classList.remove("hidden")

    this.items.forEach(({ li, rule }) => {
      const pass = rule.test(value)
      li.className = pass
        ? "flex items-center gap-1.5 text-success"
        : "flex items-center gap-1.5 text-base-content/50"
      li.querySelector("iconify-icon").setAttribute(
        "icon",
        pass ? "lucide:check-circle" : "lucide:circle"
      )
    })
  }
}
