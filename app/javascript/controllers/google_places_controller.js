import { Controller } from "@hotwired/stimulus"

const AUTOCOMPLETE_ENDPOINT = "/google_places/autocomplete"
const DETAILS_ENDPOINT = "/google_places/details"
const REVERSE_GEOCODE_ENDPOINT = "/google_places/reverse_geocode"
const MIN_QUERY_LENGTH = 2
const DEBOUNCE_MS = 250

export default class extends Controller {
  static targets = ["postcode", "status"]

  connect() {
    this.activeInput = null
    this.abortController = null
    this.debounceTimer = null
    this.onInput = this.onInput.bind(this)
    this.onFocus = this.onFocus.bind(this)
    this.onDocumentClick = this.onDocumentClick.bind(this)

    this.postcodeTargets.forEach((input) => {
      input.addEventListener("input", this.onInput)
      input.addEventListener("focus", this.onFocus)
      input.setAttribute("autocomplete", "off")
    })

    document.addEventListener("click", this.onDocumentClick)
    this.setStatus("Start typing a postcode or use current location.", "ready")
  }

  disconnect() {
    document.removeEventListener("click", this.onDocumentClick)
    window.clearTimeout(this.debounceTimer)
    this.abortController?.abort()
    this.removeSuggestions()

    this.postcodeTargets.forEach((input) => {
      input.removeEventListener("input", this.onInput)
      input.removeEventListener("focus", this.onFocus)
    })
  }

  onFocus(event) {
    this.activeInput = event.currentTarget
    this.setStatus("Type at least 2 characters to search UK addresses.", "ready")
  }

  onInput(event) {
    const input = event.currentTarget
    const query = input.value.trim()
    this.activeInput = input
    window.clearTimeout(this.debounceTimer)

    if (query.length < MIN_QUERY_LENGTH) {
      this.removeSuggestions()
      this.setStatus("Type at least 2 characters to search UK addresses.", "ready")
      return
    }

    this.debounceTimer = window.setTimeout(() => this.fetchSuggestions(input, query), DEBOUNCE_MS)
  }

  onDocumentClick(event) {
    if (!this.suggestionsList?.contains(event.target) && !this.postcodeTargets.includes(event.target)) {
      this.removeSuggestions()
    }
  }

  fetchSuggestions(input, query) {
    this.abortController?.abort()
    this.abortController = new AbortController()
    this.setStatus("Searching UK addresses...", "loading")

    fetch(`${AUTOCOMPLETE_ENDPOINT}?input=${encodeURIComponent(query)}`, {
      headers: { Accept: "application/json" },
      signal: this.abortController.signal
    })
      .then((response) => {
        if (!response.ok) throw new Error("Postcode search is temporarily unavailable")
        return response.json()
      })
      .then((data) => this.renderSuggestions(input, data.suggestions || []))
      .catch((error) => {
        if (error.name !== "AbortError") this.disableEnhancement(error)
      })
  }

  renderSuggestions(input, suggestions) {
    this.removeSuggestions()
    if (suggestions.length === 0) {
      this.setStatus("No matching UK addresses found. You can still type the postcode manually.", "ready")
      return
    }

    const list = document.createElement("div")
    list.className = "absolute z-[9999] mt-1 max-h-64 w-full overflow-y-auto rounded-xl border border-slate-200 bg-white text-sm shadow-xl shadow-slate-950/10"
    list.setAttribute("role", "listbox")

    suggestions.forEach((suggestion) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "block w-full px-3 py-2 text-left font-semibold text-slate-700 transition hover:bg-blue-50 hover:text-blue-800 focus:bg-blue-50 focus:outline-none"
      button.textContent = suggestion.description
      button.addEventListener("click", () => this.selectSuggestion(input, suggestion))
      list.appendChild(button)
    })

    const wrapper = input.parentElement
    wrapper.classList.add("relative")
    wrapper.appendChild(list)
    this.suggestionsList = list
    this.setStatus("Choose an address suggestion, or keep typing manually.", "ready")
  }

  selectSuggestion(input, suggestion) {
    this.setStatus("Filling address...", "loading")

    fetch(`${DETAILS_ENDPOINT}?place_id=${encodeURIComponent(suggestion.place_id)}`, {
      headers: { Accept: "application/json" }
    })
      .then((response) => {
        if (!response.ok) throw new Error("Address details could not be loaded")
        return response.json()
      })
      .then((place) => {
        this.fillPostcode(input, place)
        this.fillAddress(input, place)
        this.removeSuggestions()
        this.setStatus("Address filled from postcode search.", "ready")
      })
      .catch((error) => this.disableEnhancement(error))
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

    navigator.geolocation.getCurrentPosition(
      (position) => this.reverseGeocodeCurrentPosition(input, position),
      () => this.setStatus("Location permission was denied or unavailable.", "error"),
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 }
    )
  }

  fillPostcode(input, place) {
    const postcode = place?.postcode
    if (postcode) input.value = postcode.toUpperCase()
  }

  fillAddress(input, place) {
    const addressFieldId = input.dataset.googlePlacesAddressFieldId
    if (!addressFieldId || !place?.formatted_address) return

    const addressField = document.getElementById(addressFieldId)
    if (addressField) addressField.value = place.formatted_address
  }

  reverseGeocodeCurrentPosition(input, position) {
    const params = new URLSearchParams({
      lat: position.coords.latitude,
      lng: position.coords.longitude
    })

    fetch(`${REVERSE_GEOCODE_ENDPOINT}?${params}`, { headers: { Accept: "application/json" } })
      .then((response) => {
        if (!response.ok) throw new Error("Current location lookup is temporarily unavailable")
        return response.json()
      })
      .then((place) => {
        if (!place.postcode) throw new Error("No postcode was found for your current location")
        this.fillPostcode(input, place)
        this.fillAddress(input, place)
        this.setStatus("Postcode filled from your current location.", "ready")
      })
      .catch((error) => this.disableEnhancement(error))
  }

  setStatus(message, state = "ready") {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("text-rose-600", state === "error")
    this.statusTarget.classList.toggle("text-blue-700", state === "loading")
    this.statusTarget.classList.toggle("text-slate-500", state === "ready")
  }

  disableEnhancement(error) {
    this.removeSuggestions()

    const message = error?.message || "Postcode search could not be loaded"
    this.setStatus(`${message}. You can still enter the postcode manually.`, "error")
  }

  removeSuggestions() {
    this.suggestionsList?.remove()
    this.suggestionsList = null
  }
}
