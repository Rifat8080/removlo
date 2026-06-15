import { Controller } from "@hotwired/stimulus"

const SCRIPT_ID = "google-places-api"
let googlePlacesPromise

export default class extends Controller {
  static targets = ["postcode", "status"]

  connect() {
    this.onPostcodeFocus = this.onPostcodeFocus.bind(this)
    this.onPostcodeInput = this.onPostcodeInput.bind(this)
    this.onPostcodeKeydown = this.onPostcodeKeydown.bind(this)
    this.onDocumentClick = this.onDocumentClick.bind(this)
    this.suggestionLists = new Map()
    this.sessionTokens = new Map()
    this.pendingRequests = new Map()
    this.inputTimers = new Map()

    this.postcodeTargets.forEach((input) => {
      input.addEventListener("focus", this.onPostcodeFocus)
      input.addEventListener("pointerdown", this.onPostcodeFocus, { passive: true })
    })
    document.addEventListener("click", this.onDocumentClick)
    this.setStatus("Start typing a postcode or use current location.", "ready")
  }

  disconnect() {
    this.postcodeTargets.forEach((input) => {
      input.removeEventListener("focus", this.onPostcodeFocus)
      input.removeEventListener("pointerdown", this.onPostcodeFocus)
      input.removeEventListener("input", this.onPostcodeInput)
      input.removeEventListener("keydown", this.onPostcodeKeydown)
    })
    document.removeEventListener("click", this.onDocumentClick)
    this.inputTimers.forEach((timer) => clearTimeout(timer))
    this.suggestionLists.forEach((list) => list.remove())
  }

  onPostcodeFocus(event) {
    const input = event.currentTarget
    this.setStatus("Loading postcode search...", "loading")
    this.loadGooglePlaces()
      .then(() => {
        this.prepareInput(input)
        this.fetchSuggestions(input)
        this.setStatus("Start typing a postcode or address to search with Google Maps.", "ready")
      })
      .catch((error) => this.disableEnhancement(error))
  }

  onPostcodeInput(event) {
    const input = event.currentTarget
    clearTimeout(this.inputTimers.get(input))

    const timer = setTimeout(() => {
      this.loadGooglePlaces()
        .then(() => this.fetchSuggestions(input))
        .catch((error) => this.disableEnhancement(error))
    }, 180)

    this.inputTimers.set(input, timer)
  }

  onPostcodeKeydown(event) {
    const input = event.currentTarget
    const list = this.suggestionLists.get(input)
    if (!list || list.hidden) return

    const options = Array.from(list.querySelectorAll("button"))
    const currentIndex = options.findIndex((option) => option === document.activeElement)

    if (event.key === "ArrowDown") {
      event.preventDefault()
      options[Math.min(currentIndex + 1, options.length - 1)]?.focus()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      if (currentIndex <= 0) {
        input.focus()
      } else {
        options[currentIndex - 1]?.focus()
      }
    } else if (event.key === "Escape") {
      this.hideSuggestions(input)
    }
  }

  onDocumentClick(event) {
    this.postcodeTargets.forEach((input) => {
      const list = this.suggestionLists.get(input)
      if (event.target !== input && !list?.contains(event.target)) this.hideSuggestions(input)
    })
  }

  loadGooglePlaces() {
    if (window.google?.maps?.importLibrary) {
      googlePlacesPromise ||= window.google.maps.importLibrary("places")
      return googlePlacesPromise
    }
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
      script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(apiKey)}&libraries=places&v=weekly&loading=async`
      script.async = true
      script.defer = true
      script.addEventListener("load", resolve, { once: true })
      script.addEventListener("error", reject, { once: true })
      document.head.appendChild(script)
    }).then(() => window.google.maps.importLibrary("places"))

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

  prepareInput(input) {
    if (input.dataset.googlePlacesReady === "true") return

    input.dataset.googlePlacesReady = "true"
    input.setAttribute("autocomplete", "off")
    input.setAttribute("aria-autocomplete", "list")
    input.addEventListener("input", this.onPostcodeInput)
    input.addEventListener("keydown", this.onPostcodeKeydown)

    const wrapper = input.parentElement
    wrapper?.classList.add("relative")

    const list = document.createElement("div")
    list.hidden = true
    list.setAttribute("role", "listbox")
    list.className = "absolute z-50 mt-2 max-h-72 w-full overflow-y-auto rounded-2xl border border-slate-200 bg-white p-1 text-sm shadow-xl shadow-slate-900/10"
    wrapper?.appendChild(list)
    this.suggestionLists.set(input, list)
  }

  async fetchSuggestions(input) {
    this.prepareInput(input)

    const query = input.value.trim()
    if (query.length < 2) {
      this.hideSuggestions(input)
      return
    }

    const requestId = crypto.randomUUID()
    this.pendingRequests.set(input, requestId)

    try {
      const { AutocompleteSessionToken, AutocompleteSuggestion } = await this.loadGooglePlaces()
      let sessionToken = this.sessionTokens.get(input)

      if (!sessionToken) {
        sessionToken = new AutocompleteSessionToken()
        this.sessionTokens.set(input, sessionToken)
      }

      const { suggestions } = await AutocompleteSuggestion.fetchAutocompleteSuggestions({
        input: query,
        includedRegionCodes: ["gb"],
        language: "en-GB",
        region: "gb",
        sessionToken
      })

      if (this.pendingRequests.get(input) !== requestId) return
      this.renderSuggestions(input, suggestions.filter((suggestion) => suggestion.placePrediction).slice(0, 6))
    } catch (error) {
      this.hideSuggestions(input)
      this.setStatus(this.googleErrorMessage(error), "error")
    }
  }

  renderSuggestions(input, suggestions) {
    const list = this.suggestionLists.get(input)
    if (!list) return

    list.replaceChildren()
    if (!suggestions.length) {
      this.hideSuggestions(input)
      return
    }

    suggestions.forEach((suggestion) => {
      const prediction = suggestion.placePrediction
      const button = document.createElement("button")
      button.type = "button"
      button.setAttribute("role", "option")
      button.className = "block w-full rounded-xl px-3 py-2.5 text-left font-semibold text-slate-800 transition hover:bg-blue-50 focus:bg-blue-50 focus:outline-none"
      button.textContent = prediction.text.text
      button.addEventListener("click", () => this.selectSuggestion(input, prediction))
      list.appendChild(button)
    })

    list.hidden = false
  }

  async selectSuggestion(input, prediction) {
    this.setStatus("Filling selected address...", "loading")

    try {
      const place = prediction.toPlace()
      await place.fetchFields({ fields: ["addressComponents", "formattedAddress", "displayName"] })

      this.fillPostcode(input, place)
      this.fillAddress(input, place)
      this.hideSuggestions(input)
      this.sessionTokens.delete(input)
      input.dispatchEvent(new Event("change", { bubbles: true }))
      this.setStatus("Address selected from Google Maps.", "ready")
    } catch (error) {
      this.setStatus(this.googleErrorMessage(error), "error")
    }
  }

  hideSuggestions(input) {
    const list = this.suggestionLists.get(input)
    if (list) list.hidden = true
  }

  fillPostcode(input, place) {
    const postcode = this.componentValue(place, "postal_code") || this.postcodeFromText(place?.formattedAddress || place?.formatted_address || "")
    if (postcode) input.value = postcode.toUpperCase()
  }

  fillAddress(input, place) {
    const addressFieldId = input.dataset.googlePlacesAddressFieldId
    const formattedAddress = place?.formattedAddress || place?.formatted_address
    if (!addressFieldId || !formattedAddress) return

    const addressField = document.getElementById(addressFieldId)
    if (addressField) addressField.value = formattedAddress
  }

  componentValue(place, type) {
    const components = place?.addressComponents || place?.address_components || []
    const component = components.find((addressComponent) => addressComponent.types.includes(type))
    return component?.longText || component?.long_name || ""
  }

  postcodeFromText(text) {
    return text.match(/[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2}/i)?.[0] || ""
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
    this.setStatus(`${message}. Check GOOGLE_MAPS_BROWSER_KEY and enable Maps JavaScript API + Places API.`, "error")
  }

  googleErrorMessage(error) {
    const message = error?.message || "Google Places could not load suggestions"
    if (message.includes("ApiTargetBlockedMapError")) {
      return "This API key is blocked from Google Places. Enable Places API (New) and allow it in the browser key restrictions."
    }

    return message
  }
}
