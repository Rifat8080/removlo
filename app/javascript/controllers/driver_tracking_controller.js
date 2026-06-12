import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "startButton", "stopButton"]
  static values = {
    url: String,
    interval: { type: Number, default: 30000 }
  }

  connect() {
    this.watchId = null
    this.timerId = null
    this.latestPosition = null
  }

  disconnect() {
    this.stop()
  }

  start() {
    if (!navigator.geolocation) {
      this.setStatus("Geolocation is not supported in this browser.", "error")
      return
    }

    this.setStatus("Requesting location permission...", "loading")

    this.watchId = navigator.geolocation.watchPosition(
      (position) => {
        this.latestPosition = position
        this.sendLocation(position)
        this.setStatus("Sharing live location with the customer.", "ready")
      },
      (error) => this.setStatus(this.geolocationError(error), "error"),
      { enableHighAccuracy: true, maximumAge: 10000, timeout: 15000 }
    )

    this.timerId = window.setInterval(() => {
      if (this.latestPosition) this.sendLocation(this.latestPosition)
    }, this.intervalValue)
  }

  stop() {
    if (this.watchId !== null) {
      navigator.geolocation.clearWatch(this.watchId)
      this.watchId = null
    }

    if (this.timerId !== null) {
      window.clearInterval(this.timerId)
      this.timerId = null
    }

    this.setStatus("Location sharing is off.", "ready")
  }

  sendLocation(position) {
    if (!this.urlValue) return

    const body = {
      latitude: position.coords.latitude,
      longitude: position.coords.longitude,
      accuracy: position.coords.accuracy,
      heading: position.coords.heading,
      speed: position.coords.speed
    }

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken(),
        Accept: "application/json"
      },
      body: JSON.stringify(body)
    }).catch(() => {
      this.setStatus("Could not send location update.", "error")
    })
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }

  geolocationError(error) {
    if (error.code === error.PERMISSION_DENIED) return "Location permission was denied."
    if (error.code === error.POSITION_UNAVAILABLE) return "Location is unavailable."
    if (error.code === error.TIMEOUT) return "Location request timed out."
    return "Could not access your location."
  }

  setStatus(message, state = "ready") {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("text-rose-600", state === "error")
    this.statusTarget.classList.toggle("text-indigo-700", state === "loading")
    this.statusTarget.classList.toggle("text-slate-500", state === "ready")
  }
}
