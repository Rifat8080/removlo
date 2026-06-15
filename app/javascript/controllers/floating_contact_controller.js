import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    storageKey: { type: String, default: "removlo:floating-contact-dismissed-session" }
  }

  connect() {
    if (this.dismissed) this.element.remove()
  }

  close() {
    sessionStorage.setItem(this.storageKeyValue, "true")
    this.element.remove()
  }

  get dismissed() {
    return sessionStorage.getItem(this.storageKeyValue) === "true"
  }
}
