import { Controller } from "@hotwired/stimulus"

// The feed's compose box. Picks when the instruction runs — now (one-off) or a recurring preset — and keeps the
// hidden `every` field, the dropdown label, and the submit button in sync. "daily" reveals a time input.
export default class extends Controller {
  static targets = ["every", "label", "submit", "dailyRow", "dailyTime", "menu", "instruction", "dialog"]
  static values = { labels: Object }

  // Open the full task editor (name, schedule, model, details) in a modal, carrying over whatever's already typed.
  openAdvanced() {
    const typed = this.hasInstructionTarget ? this.instructionTarget.value.trim() : ""
    const field = this.dialogTarget.querySelector('[name="agent_task[instruction]"]')
    if (field && typed) field.value = typed
    this.dialogTarget.showModal()
    field?.focus()
  }

  choose(event) {
    event.preventDefault()
    const key = event.currentTarget.dataset.key
    this.everyTarget.value = key
    this.dailyRowTarget.classList.toggle("hidden", key !== "daily")
    this.render(key)
    if (this.hasMenuTarget) this.menuTarget.open = false
  }

  dailyChanged() {
    this.render("daily")
  }

  render(key) {
    const label = key === "daily"
      ? `Daily at ${this.dailyTimeTarget.value || "09:00"}`
      : (this.labelsValue[key] || "Run now")
    this.labelTarget.textContent = label
    this.submitTarget.textContent = key === "now" ? "Run" : "Schedule"
  }
}
