import { Controller } from "@hotwired/stimulus"

// Point-of-use voucher code: counts the code down and polls until the counter
// verifies it, then reloads to show the "đã dùng" confirmation.
export default class extends Controller {
  static targets = ["count"]
  static values = { statusUrl: String, seconds: Number, returnUrl: String }

  connect() {
    this.remaining = this.secondsValue
    this.timer = setInterval(() => this.tick(), 1000)
    this.poller = setInterval(() => this.poll(), 2500)
  }

  disconnect() {
    clearInterval(this.timer)
    clearInterval(this.poller)
  }

  tick() {
    this.remaining -= 1
    if (this.hasCountTarget) this.countTarget.textContent = Math.max(this.remaining, 0)
    if (this.remaining <= 0) { clearInterval(this.timer); this.reload() }
  }

  async poll() {
    try {
      const res = await fetch(this.statusUrlValue, { headers: { Accept: "application/json" } })
      const data = await res.json()
      if (data.state === "used") { if (navigator.vibrate) navigator.vibrate(80); this.reload() }
    } catch (e) { /* ignore */ }
  }

  reload() {
    if (window.Turbo) window.Turbo.visit(this.returnUrlValue, { action: "replace" })
    else window.location.href = this.returnUrlValue
  }
}
