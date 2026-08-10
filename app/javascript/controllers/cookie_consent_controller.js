import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["banner"]
  static values = {
    storageKey: { type: String, default: "removlo:analytics-consent" },
    region: { type: Boolean, default: false }
  }

  connect() {
    this.element.classList.remove("hidden")
    this.openHandler = () => this.showBanner()
    document.addEventListener("cookie-consent:open", this.openHandler)

    this.resizeObserver = new ResizeObserver(() => this.updateBannerOffset())

    if (!this.regionValue || this.storedConsent) {
      this.hideBanner()
      return
    }

    this.showBanner()
  }

  disconnect() {
    document.removeEventListener("cookie-consent:open", this.openHandler)
    this.stopObservingBanner()
    this.clearBannerOffset()
  }

  accept() {
    this.persistConsent("granted")
    this.updateAnalyticsConsent(true)
    window.RemoAnalytics?.trackPageView()
    this.hideBanner()
  }

  reject() {
    this.persistConsent("denied")
    this.updateAnalyticsConsent(false)
    this.hideBanner()
  }

  showBanner() {
    if (!this.hasBannerTarget) return

    this.bannerTarget.classList.remove("hidden")
    document.documentElement.classList.add("cookie-consent-visible")
    this.resizeObserver.observe(this.bannerTarget)
    this.updateBannerOffset()
  }

  hideBanner() {
    if (this.hasBannerTarget) this.bannerTarget.classList.add("hidden")
    document.documentElement.classList.remove("cookie-consent-visible")
    this.stopObservingBanner()
    this.clearBannerOffset()
  }

  updateBannerOffset() {
    if (!this.hasBannerTarget || this.bannerTarget.classList.contains("hidden")) return

    document.documentElement.style.setProperty(
      "--cookie-consent-height",
      `${Math.ceil(this.bannerTarget.getBoundingClientRect().height)}px`
    )
  }

  stopObservingBanner() {
    if (this.hasBannerTarget) this.resizeObserver?.unobserve(this.bannerTarget)
  }

  clearBannerOffset() {
    document.documentElement.style.removeProperty("--cookie-consent-height")
  }

  persistConsent(value) {
    try {
      localStorage.setItem(this.storageKeyValue, value)
    } catch (_error) {
      // Ignore storage failures (private browsing, blocked storage).
    }
  }

  updateAnalyticsConsent(granted) {
    if (window.RemoAnalytics) window.RemoAnalytics.applyConsent(granted)
  }

  get storedConsent() {
    try {
      return localStorage.getItem(this.storageKeyValue)
    } catch (_error) {
      return null
    }
  }
}
