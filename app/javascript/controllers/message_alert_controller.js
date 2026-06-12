import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    title: String,
    body: String,
    url: String,
    tag: String,
    sentByViewer: Boolean
  }

  connect() {
    if (this.sentByViewerValue || !this.shouldAlert()) return

    this.showAlert()
    this.element.remove()
  }

  shouldAlert() {
    if (!window.location.pathname.startsWith("/conversations")) return false

    try {
      const conversationPath = new URL(this.urlValue, window.location.origin).pathname
      return window.location.pathname !== conversationPath
    } catch (_error) {
      return true
    }
  }

  showAlert() {
    const toast = document.createElement("a")
    toast.href = this.urlValue
    toast.className = [
      "fixed bottom-5 right-5 z-[60] w-[min(24rem,calc(100vw-2rem))]",
      "rounded-3xl border border-slate-200 bg-white p-4 text-slate-800 shadow-2xl shadow-slate-900/20 ring-1 ring-slate-900/5",
      "transition hover:-translate-y-0.5 hover:border-indigo-200 hover:shadow-indigo-950/20"
    ].join(" ")
    toast.innerHTML = `
      <div class="flex gap-3">
        <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-2xl bg-indigo-600 text-sm font-black text-white">M</span>
        <span class="min-w-0 flex-1">
          <span class="block text-sm font-black text-slate-900">${this.escapeHtml(this.titleValue)}</span>
          <span class="mt-1 block truncate text-sm text-slate-600">${this.escapeHtml(this.bodyValue)}</span>
          <span class="mt-2 block text-xs font-bold text-indigo-600">Open conversation</span>
        </span>
      </div>
    `

    document.body.appendChild(toast)
    setTimeout(() => toast.remove(), 8000)
  }

  escapeHtml(value) {
    const div = document.createElement("div")
    div.textContent = value || ""
    return div.innerHTML
  }
}
