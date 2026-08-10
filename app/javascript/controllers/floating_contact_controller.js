import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "trigger", "label", "openIcon", "closeIcon"]

  connect() {
    this.open = false
    this.render()
  }

  toggle() {
    this.open ? this.close() : this.show()
  }

  show() {
    this.open = true
    this.render()
  }

  close() {
    if (!this.open) return

    this.open = false
    this.render()
    this.triggerTarget.focus({ preventScroll: true })
  }

  select() {
    this.open = false
    this.render()
  }

  dismissOnOutsideClick(event) {
    if (this.open && !this.element.contains(event.target)) {
      this.open = false
      this.render()
    }
  }

  dismissWithKeyboard() {
    if (this.open) this.close()
  }

  prepareForCache() {
    this.open = false
    this.render()
  }

  render() {
    if (!this.hasPanelTarget || !this.hasTriggerTarget) return

    this.panelTarget.classList.toggle("is-open", this.open)
    this.panelTarget.setAttribute("aria-hidden", String(!this.open))
    this.panelTarget.toggleAttribute("inert", !this.open)
    this.triggerTarget.setAttribute("aria-expanded", String(this.open))
    this.triggerTarget.setAttribute("aria-label", this.open ? "Close contact options" : "Open contact options")

    if (this.hasLabelTarget) this.labelTarget.textContent = this.open ? "Close" : "Contact us"
    if (this.hasOpenIconTarget) this.openIconTarget.classList.toggle("hidden", this.open)
    if (this.hasCloseIconTarget) this.closeIconTarget.classList.toggle("hidden", !this.open)
  }
}
