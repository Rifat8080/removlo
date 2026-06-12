import { Controller } from "@hotwired/stimulus"

const SCRIPT_ID = "google-places-api"
let googlePlacesPromise

export default class extends Controller {
  static targets = ["postcode", "status"]

  connect() {
    this.loadGooglePlaces()
      .then(() => {
        this.setupAutocomplete()
        this.setStatus("Start typing a postcode or address to search with Google Maps.", "ready")
      })
      .catch((error) => this.disableEnhancement(error))
  }

  loadGooglePlaces() {
    if (window.google?.maps?.places) return Promise.resolve()
    if (googlePlacesPromise) return googlePlacesPromise

    const apiKey = document.querySelector("meta[name='google-maps-browser-key']")?.content
    if (!apiKey) return Promise.reject(new Error("Missing GOOGLE_MAPS_BROWSER_KEY"))

    googlePlacesPromise = new Promise((resolve, reject) => {
      const existingScript = document.getElementById(SCRIPT_ID)
      if (existingScript) {
        existingScript.addEventListener("load", resolve, { once: true })
        existingScript.addEventListener("error", reject, { once: true })
        return
      }

      const script = document.createElement("script")
      script.id = SCRIPT_ID
      script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(apiKey)}&libraries=places&v=weekly`
      script.async = true
      script.defer = true
      script.addEventListener("load", resolve, { once: true })
      script.addEventListener("error", reject, { once: true })
      document.head.appendChild(script)
    })

    return googlePlacesPromise
  }

  useCurrentLocation(event) {
    const inputId = event.params.input
    const input = document.getElementById(inputId)
    if (!input) return

    if (!navigator.geolocation) {
      this.setStatus("Your browser does not support current location lookup.", "error")
      return
    }

    this.setStatus("Finding your current postcode...", "loading")

    this.loadGooglePlaces()
      .then(() => {
        navigator.geolocation.getCurrentPosition(
          (position) => this.geocodeCurrentPosition(input, position),
          () => this.setStatus("Location permission was denied or unavailable.", "error"),
          { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 }
        )
      })
      .catch((error) => this.disableEnhancement(error))
  }

  setupAutocomplete() {
    this.postcodeTargets.forEach((input) => {
      if (input.dataset.googlePlacesReady === "true") return

      const autocomplete = new window.google.maps.places.Autocomplete(input, {
        componentRestrictions: { country: "gb" },
        fields: ["address_components", "formatted_address", "name"],
        types: ["geocode"]
      })

      autocomplete.addListener("place_changed", () => {
        const place = autocomplete.getPlace()
        this.fillPostcode(input, place)
        this.fillAddress(input, place)
      })

      input.dataset.googlePlacesReady = "true"
      input.setAttribute("autocomplete", "off")
    })
  }

  fillPostcode(input, place) {
    const postcode = this.componentValue(place, "postal_code")
    if (postcode) input.value = postcode.toUpperCase()
  }

  fillAddress(input, place) {
    const addressFieldId = input.dataset.googlePlacesAddressFieldId
    if (!addressFieldId || !place?.formatted_address) return

    const addressField = document.getElementById(addressFieldId)
    if (addressField) addressField.value = place.formatted_address
  }

  componentValue(place, type) {
    const component = place?.address_components?.find((addressComponent) => addressComponent.types.includes(type))
    return component?.long_name || ""
  }

  geocodeCurrentPosition(input, position) {
    const geocoder = new window.google.maps.Geocoder()
    const location = {
      lat: position.coords.latitude,
      lng: position.coords.longitude
    }

    geocoder.geocode({ location }, (results, status) => {
      if (status !== "OK" || !results?.length) {
        this.setStatus("Google Maps could not find a postcode for this location.", "error")
        return
      }

      const result = results.find((item) => this.componentValue(item, "postal_code")) || results[0]
      this.fillPostcode(input, result)
      this.fillAddress(input, result)
      this.setStatus("Postcode filled from your current location.", "ready")
    })
  }

  setStatus(message, state = "ready") {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("text-rose-600", state === "error")
    this.statusTarget.classList.toggle("text-blue-700", state === "loading")
    this.statusTarget.classList.toggle("text-slate-500", state === "ready")
  }

  disableEnhancement(error) {
    this.postcodeTargets.forEach((input) => {
      input.removeAttribute("data-google-places-target")
    })

    const message = error?.message || "Google Maps could not be loaded"
    this.setStatus(`${message}. Add GOOGLE_MAPS_BROWSER_KEY to .env and restart Rails to enable postcode search.`, "error")
  }
}
