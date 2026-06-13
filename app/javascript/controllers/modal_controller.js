import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  open() {
    if (!this.hasDialogTarget) return

    this.dialogTarget.showModal()
  }

  close() {
    if (!this.hasDialogTarget) return

    this.dialogTarget.close()
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
