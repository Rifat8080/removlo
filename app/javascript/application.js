// Entry point — loaded via importmap on every layout.
import "@hotwired/turbo-rails"
import "controllers"
import { initFlowbite } from "flowbite"

document.documentElement.classList.add("js")

const initializeFlowbite = () => {
  initFlowbite()
}

document.addEventListener("turbo:load", initializeFlowbite)
document.addEventListener("turbo:frame-load", initializeFlowbite)
