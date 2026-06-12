import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template"]

  add() {
    const content = this.templateTarget.innerHTML.replaceAll("NEW_RECORD", Date.now().toString())
    this.listTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    const row = event.target.closest("[data-quotation-items-target='row']")
    if (!row) return

    const persistedField = row.querySelector("input[name$='[id]']")
    const destroyField = row.querySelector("input[name$='[_destroy]']")

    if (persistedField && destroyField) {
      destroyField.value = "1"
      row.hidden = true
    } else {
      row.remove()
    }
  }
}
