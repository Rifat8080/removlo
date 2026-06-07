import { Controller } from "@hotwired/stimulus"

// Adds a scrolled state to the landing navbar after the user scrolls past the top.
export default class extends Controller {
  connect() {
    this.onScroll = this.onScroll.bind(this)
    this.onScroll()
    window.addEventListener("scroll", this.onScroll, { passive: true })
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  onScroll() {
    const scrolled = window.scrollY > 8

    this.element.classList.toggle("bg-white/95", scrolled)
    this.element.classList.toggle("bg-white/90", !scrolled)
    this.element.classList.toggle("shadow-lg", scrolled)
    this.element.classList.toggle("shadow-slate-900/5", scrolled)
    this.element.classList.toggle("border-slate-200/80", scrolled)
  }
}
