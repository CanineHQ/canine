export function setConfirmModal(Turbo) {
  Turbo.config.forms.confirm = (message, element, submitter) => {
    const dialog = document.getElementById("turbo-confirm-modal")

    if (!dialog) return Promise.resolve(false)

    const source = submitter || element
    const title = source?.dataset?.confirmTitle
    const type = source?.dataset?.confirmType || "primary"

    const titleEl = dialog.querySelector("[data-confirm-title]")
    const messageEl = dialog.querySelector("[data-confirm-message]")
    const confirmBtn = dialog.querySelector("[data-confirm-accept]")

    if (titleEl) titleEl.textContent = title || "Confirm"
    messageEl.textContent = message
    confirmBtn.className = `btn btn-${type}`

    dialog.showModal()

    return new Promise((resolve) => {
      const handleConfirm = () => {
        cleanup()
        dialog.close()
        resolve(true)
      }

      const handleCancel = () => {
        cleanup()
        resolve(false)
      }

      const cleanup = () => {
        confirmBtn.removeEventListener("click", handleConfirm)
        dialog.removeEventListener("close", handleCancel)
      }

      confirmBtn.addEventListener("click", handleConfirm, { once: true })
      dialog.addEventListener("close", handleCancel, { once: true })
    })
  }
}
