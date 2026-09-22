// Entry point — loaded via importmap on every layout.
import "@hotwired/turbo-rails"
import "controllers"

document.documentElement.classList.add("js")

const runWhenIdle = (callback) => {
  if ("requestIdleCallback" in window) {
    window.requestIdleCallback(callback, { timeout: 1800 })
  } else {
    window.setTimeout(callback, 700)
  }
}

const initializeFlowbite = () => {
  runWhenIdle(() => {
    import("flowbite").then(({ initFlowbite }) => initFlowbite())
  })
}

const wordCount = (value) => {
  const words = value.match(/[\p{Letter}\p{Number}'-]+/gu)
  return words ? words.length : 0
}

const updateWordCount = (input) => {
  const container = input.closest("[data-word-count]")
  if (!container) return

  const count = wordCount(input.value)
  const minimum = Number.parseInt(container.dataset.wordCountMinimum || "0", 10)
  const countElement = container.querySelector("[data-word-count-count]")
  const statusElement = container.querySelector("[data-word-count-status]")

  if (countElement) countElement.textContent = count.toString()

  if (statusElement) {
    statusElement.classList.toggle("text-emerald-700", count >= minimum)
    statusElement.classList.toggle("text-amber-700", count < minimum)
  }
}

const initializeWordCounts = () => {
  document.querySelectorAll("[data-word-count-input]").forEach(updateWordCount)
}

document.addEventListener("turbo:load", initializeFlowbite)
document.addEventListener("turbo:frame-load", initializeFlowbite)
document.addEventListener("turbo:load", initializeWordCounts)
document.addEventListener("turbo:frame-load", initializeWordCounts)
document.addEventListener("input", (event) => {
  if (event.target.matches("[data-word-count-input]")) {
    updateWordCount(event.target)
  }
})
