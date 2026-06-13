import { Controller } from "@hotwired/stimulus"

// Scroll-reveal for elements with class "reveal" inside the controller scope.
export default class extends Controller {
  connect() {
    this.observer = null
    this.idleCallback = null
    this.idleTimer = null

    if ("requestIdleCallback" in window) {
      this.idleCallback = window.requestIdleCallback(() => this.initReveal(), { timeout: 1200 })
    } else {
      this.idleTimer = window.setTimeout(() => this.initReveal(), 500)
    }
  }

  disconnect() {
    if (this.idleCallback) window.cancelIdleCallback(this.idleCallback)
    if (this.idleTimer) window.clearTimeout(this.idleTimer)
    this.observer?.disconnect()
  }

  initReveal() {
    const elements = this.element.querySelectorAll(".reveal")

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      elements.forEach((el) => el.classList.add("is-visible"))
      return
    }

    if (!("IntersectionObserver" in window)) {
      elements.forEach((el) => el.classList.add("is-visible"))
      return
    }

    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible")
            this.observer.unobserve(entry.target)
          }
        })
      },
      { threshold: 0.12, rootMargin: "0px 0px -8% 0px" }
    )

    elements.forEach((el) => this.observer.observe(el))
  }
}
