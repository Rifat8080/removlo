import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "count", "status"]
  static values = {
    minimum: Number
  }

  connect() {
    this.update()
  }

  update() {
    const count = this.wordCount(this.inputTarget.value)
    const minimum = this.minimumValue || 0

    this.countTarget.textContent = count.toString()

    if (this.hasStatusTarget) {
      this.statusTarget.classList.toggle("text-emerald-700", count >= minimum)
      this.statusTarget.classList.toggle("text-amber-700", count < minimum)
    }
  }

  wordCount(value) {
    const words = value.match(/[\p{Letter}\p{Number}'-]+/gu)
    return words ? words.length : 0
  }
}
