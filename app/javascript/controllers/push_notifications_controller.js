import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "status"]

  async connect() {
    if (!this.supported) {
      this.updateState("Push not supported", true)
      return
    }

    const registration = await navigator.serviceWorker.register("/service-worker.js")
    this.registration = registration
    const subscription = await registration.pushManager.getSubscription()
    this.updateState(subscription ? "Push enabled" : "Enable push", false)
  }

  async subscribe() {
    if (!this.supported || !this.registration) return

    this.updateState("Requesting permission...", true)
    const permission = await Notification.requestPermission()
    if (permission !== "granted") {
      this.updateState("Push blocked", false)
      return
    }

    const response = await fetch("/web_push/config")
    const config = await response.json()
    if (!config.enabled || !config.public_key) {
      this.updateState("Push keys missing", false)
      return
    }

    const subscription = await this.registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: this.urlBase64ToUint8Array(config.public_key)
    })

    await fetch("/web_push_subscription", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify({ subscription: subscription.toJSON() })
    })

    this.updateState("Push enabled", false)
  }

  get supported() {
    return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }

  updateState(message, disabled) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
    if (this.hasButtonTarget) this.buttonTarget.disabled = disabled
  }

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const rawData = window.atob(base64)
    const outputArray = new Uint8Array(rawData.length)

    for (let i = 0; i < rawData.length; i++) {
      outputArray[i] = rawData.charCodeAt(i)
    }

    return outputArray
  }
}
