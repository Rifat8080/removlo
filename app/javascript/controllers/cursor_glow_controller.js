import { Controller } from "@hotwired/stimulus"

// Drives the soft ambient glow on the landing page without inline scripts.
export default class extends Controller {
  connect() {
    this.onPointerMove = this.onPointerMove.bind(this)
    this.frame = null

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    if (!window.matchMedia("(pointer: fine)").matches) return

    window.addEventListener("pointermove", this.onPointerMove, { passive: true })
  }

  disconnect() {
    window.removeEventListener("pointermove", this.onPointerMove)
    if (this.frame) cancelAnimationFrame(this.frame)
  }

  onPointerMove(event) {
    this.cursorX = event.clientX
    this.cursorY = event.clientY

    if (this.frame) return

    this.frame = requestAnimationFrame(() => {
      document.documentElement.style.setProperty("--cursor-x", `${this.cursorX}px`)
      document.documentElement.style.setProperty("--cursor-y", `${this.cursorY}px`)
      this.frame = null
    })
  }
}
