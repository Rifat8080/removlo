import { Controller } from "@hotwired/stimulus"

// Drives the soft ambient glow on the landing page without inline scripts.
export default class extends Controller {
  connect() {
    this.onPointerMove = this.onPointerMove.bind(this)

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    window.addEventListener("pointermove", this.onPointerMove, { passive: true })
  }

  disconnect() {
    window.removeEventListener("pointermove", this.onPointerMove)
  }

  onPointerMove(event) {
    document.documentElement.style.setProperty("--cursor-x", `${event.clientX}px`)
    document.documentElement.style.setProperty("--cursor-y", `${event.clientY}px`)
  }
}
