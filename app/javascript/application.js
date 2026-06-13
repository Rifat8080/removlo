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

document.addEventListener("turbo:load", initializeFlowbite)
document.addEventListener("turbo:frame-load", initializeFlowbite)
