import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.visible = null
    this.onScroll = this.onScroll.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  scroll() {
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    window.scrollTo({ top: 0, behavior: reduceMotion ? "auto" : "smooth" })
  }

  onScroll() {
    if (!this.hasButtonTarget) return

    const visible = window.scrollY >= 300
    if (visible === this.visible) return

    this.visible = visible
    this.buttonTarget.classList.toggle("opacity-0", !visible)
    this.buttonTarget.classList.toggle("pointer-events-none", !visible)
    this.buttonTarget.classList.toggle("translate-y-2", !visible)
    this.buttonTarget.setAttribute("aria-hidden", String(!visible))

    if (visible) {
      this.buttonTarget.removeAttribute("tabindex")
    } else {
      this.buttonTarget.setAttribute("tabindex", "-1")
    }
  }
}
