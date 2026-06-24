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

    if (!this.regionValue || this.storedConsent) {
      this.hideBanner()
      return
    }

    this.showBanner()
  }

  disconnect() {
    document.removeEventListener("cookie-consent:open", this.openHandler)
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
  }

  hideBanner() {
    if (this.hasBannerTarget) this.bannerTarget.classList.add("hidden")
    document.documentElement.classList.remove("cookie-consent-visible")
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
