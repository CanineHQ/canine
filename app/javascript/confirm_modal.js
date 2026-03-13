export function setConfirmModal(Turbo) {
  Turbo.setConfirmMethod((message, element) => {
    const dialog = document.getElementById("turbo-confirm-modal")

    if (!dialog) return Promise.resolve(false)

    const messageEl = dialog.querySelector("[data-confirm-message]")
    const confirmBtn = dialog.querySelector("[data-confirm-accept]")

    messageEl.textContent = message

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
  })
}
