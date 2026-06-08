import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "status"]
  static values = {
    timeout: { type: Number, default: 10000 }
  }

  async connect() {
    if (!this.supported) {
      this.updateState("Push not supported", true, false)
      return
    }

    this.updateState("Enable alerts", false, false)
    this.initializePromise = this.initialize()
  }

  async initialize() {
    try {
      this.registration = await this.withTimeout(
        navigator.serviceWorker.register("/service-worker.js", { scope: "/" }),
        "Service worker registration timed out"
      )

      await this.withTimeout(navigator.serviceWorker.ready, "Service worker was not ready in time")

      const subscription = await this.registration.pushManager.getSubscription()
      if (Notification.permission === "granted" && subscription) {
        this.syncSubscription(subscription).catch((error) => {
          console.warn("Push subscription sync failed", error)
        })
        this.updateState("Alerts on", false, true)
      } else if (Notification.permission === "denied") {
        this.updateState("Blocked in browser settings", true, false)
      } else {
        this.updateState("Enable alerts", false, false)
      }
    } catch (error) {
      console.error("Push setup failed", error)
      this.updateState("Enable alerts", false, false)
    }
  }

  async subscribe() {
    if (!this.supported) return

    try {
      if (this.subscribed) {
        await this.unsubscribe()
        return
      }

      this.updateState("Opening browser prompt...", true, false)
      if (!this.registration) await this.initializePromise
      if (!this.registration) throw new Error("Service worker is not registered")

      const permission = await this.withTimeout(
        Notification.requestPermission(),
        "Notification permission request timed out"
      )
      if (permission !== "granted") {
        this.updateState(permission === "denied" ? "Blocked in browser settings" : "Enable alerts", permission === "denied", false)
        return
      }

      this.updateState("Connecting alerts...", true, false)
      const config = await this.fetchConfig()
      if (!config.enabled || !config.public_key) {
        this.updateState("Push keys missing", false, false)
        return
      }

      let subscription = await this.registration.pushManager.getSubscription()
      if (!subscription) {
        subscription = await this.withTimeout(
          this.registration.pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey: this.urlBase64ToUint8Array(config.public_key)
          }),
          "Browser push subscription timed out"
        )
      }

      await this.syncSubscription(subscription)
      this.updateState("Alerts on", false, true)
    } catch (error) {
      console.error("Push subscription failed", error)
      this.updateState("Could not enable alerts", false, false)
    }
  }

  async unsubscribe() {
    try {
      this.updateState("Turning alerts off...", true, true)
      const subscription = await this.registration.pushManager.getSubscription()
      if (subscription) {
        await this.deleteSubscription(subscription)
        await subscription.unsubscribe()
      }

      this.updateState("Enable alerts", false, false)
    } catch (error) {
      console.error("Push unsubscribe failed", error)
      this.updateState("Alerts on", false, true)
    }
  }

  async fetchConfig() {
    const response = await this.fetchWithTimeout("/web_push/config", {
      credentials: "same-origin",
      headers: { "Accept": "application/json" }
    })

    if (!response.ok) throw new Error("Push config request failed")
    return response.json()
  }

  async syncSubscription(subscription) {
    const response = await this.fetchWithTimeout("/web_push_subscription", {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify({ subscription: subscription.toJSON() })
    })

    if (!response.ok) throw new Error("Subscription sync failed")
  }

  async deleteSubscription(subscription) {
    await this.fetchWithTimeout("/web_push_subscription", {
      method: "DELETE",
      credentials: "same-origin",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify({ endpoint: subscription.endpoint })
    })
  }

  get supported() {
    return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }

  updateState(message, disabled, subscribed) {
    this.subscribed = subscribed
    if (this.hasStatusTarget) this.statusTarget.textContent = message
    if (this.hasButtonTarget) this.buttonTarget.disabled = disabled
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-pressed", subscribed ? "true" : "false")
  }

  async fetchWithTimeout(url, options = {}) {
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), this.timeoutValue)

    try {
      return await fetch(url, { ...options, signal: controller.signal })
    } finally {
      clearTimeout(timeout)
    }
  }

  withTimeout(promise, message) {
    let timeout
    const timeoutPromise = new Promise((_, reject) => {
      timeout = setTimeout(() => reject(new Error(message)), this.timeoutValue)
    })

    return Promise.race([promise, timeoutPromise]).finally(() => clearTimeout(timeout))
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
