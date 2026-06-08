import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "panel", "title", "subtitle", "submit"]

  connect() {
    this.refresh()
  }

  select(event) {
    const input = event.currentTarget.querySelector("input[type='radio']")
    if (input) input.checked = true

    this.refresh()
  }

  refresh() {
    const selected = this.selectedRole

    this.cardTargets.forEach((card) => {
      const active = card.dataset.role === selected
      card.classList.toggle("border-indigo-500", active)
      card.classList.toggle("bg-indigo-50", active)
      card.classList.toggle("shadow-indigo-100", active)
      card.classList.toggle("border-slate-200", !active)
      card.classList.toggle("bg-white", !active)
    })

    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.role !== selected)
    })

    this.titleTarget.textContent = selected === "driver" ? "Join Removlo as a driver" : "Create your customer account"
    this.subtitleTarget.textContent =
      selected === "driver" ?
        "Receive moving jobs, submit offers, manage availability, and track payouts." :
        "Get quotes, pay deposits, message support, and track your move from start to finish."
    this.submitTarget.value = selected === "driver" ? "Create driver account" : "Create customer account"
  }

  get selectedRole() {
    const selectedInput = this.element.querySelector("input[name='user[role]']:checked")
    return selectedInput?.value || "customer"
  }
}
