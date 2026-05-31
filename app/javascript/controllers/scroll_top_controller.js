import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.onScroll = this.onScroll.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  scroll() {
    window.scrollTo({ top: 0, behavior: "smooth" })
  }

  onScroll() {
    if (!this.hasButtonTarget) return

    this.buttonTarget.classList.toggle("opacity-0", window.scrollY < 300)
    this.buttonTarget.classList.toggle("pointer-events-none", window.scrollY < 300)
    this.buttonTarget.classList.toggle("translate-y-2", window.scrollY < 300)
  }
}
