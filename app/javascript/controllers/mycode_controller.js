import { Controller } from "@hotwired/stimulus"

// "Mã của tôi": rotates the personal QR on a countdown (so a screenshot can't be
// reused) and polls for a fresh earn to reveal a "+X điểm" burst on the phone.
export default class extends Controller {
  static targets = ["qr", "count", "burst", "burstPoints", "burstBalance"]
  static values = { tokenUrl: String, recentUrl: String, since: Number, ttl: Number }

  connect() {
    this.remaining = this.ttlValue
    this.countdown = setInterval(() => this.tick(), 1000)
    this.poller = setInterval(() => this.pollEarn(), 3000)
  }

  disconnect() {
    clearInterval(this.countdown)
    clearInterval(this.poller)
  }

  tick() {
    this.remaining -= 1
    if (this.remaining <= 0) { this.rotate(); this.remaining = this.ttlValue }
    if (this.hasCountTarget) this.countTarget.textContent = this.remaining
  }

  async rotate() {
    try {
      const res = await fetch(this.tokenUrlValue, { headers: { Accept: "application/json" } })
      const data = await res.json()
      if (data.svg) this.qrTarget.innerHTML = data.svg
    } catch (e) { /* keep old QR */ }
  }

  async pollEarn() {
    try {
      const res = await fetch(`${this.recentUrlValue}?since=${this.sinceValue}`,
                             { headers: { Accept: "application/json" } })
      const data = await res.json()
      if (data.earned) {
        this.sinceValue = data.at
        this.reveal(data.earned, data.balance)
      }
    } catch (e) { /* ignore */ }
  }

  reveal(points, balance) {
    this.burstPointsTarget.textContent = points.toLocaleString("vi-VN")
    this.burstBalanceTarget.textContent = balance.toLocaleString("vi-VN")
    const el = this.burstTarget
    el.style.display = "flex"
    el.animate([{ opacity: 0, transform: "scale(1.15)" }, { opacity: 1, transform: "scale(1)" }],
               { duration: 300, easing: "ease-out" })
    if (navigator.vibrate) navigator.vibrate(60)
    // Keep the result on screen until the customer taps OK (or leaves) — pause
    // the QR rotation + earn polling so nothing overwrites it behind the burst.
    clearInterval(this.countdown)
    clearInterval(this.poller)
  }

  // Tap "OK": hide the result and resume the rotating QR + earn polling.
  dismiss() {
    const el = this.burstTarget
    el.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 300 }).onfinish = () => { el.style.display = "none" }
    this.remaining = this.ttlValue
    this.rotate()
    this.countdown = setInterval(() => this.tick(), 1000)
    this.poller = setInterval(() => this.pollEarn(), 3000)
  }
}
