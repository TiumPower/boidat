import { Controller } from "@hotwired/stimulus"

// Lucky wheel: POSTs a spin, then rotates the SVG so the winning segment lands
// under the pointer and reveals the prize with confetti.
export default class extends Controller {
  static targets = ["wheel", "btn", "result", "hint"]
  static values = { spinUrl: String, count: Number, cost: Number }

  connect() { this.rotation = 0; this.spinning = false }

  async spin() {
    if (this.spinning) return
    this.spinning = true
    this.audio() // unlock/resume AudioContext inside the user gesture (mobile/iOS)
    this.btnTarget.disabled = true
    this.resultTarget.textContent = ""

    let data
    try {
      const res = await fetch(this.spinUrlValue, {
        method: "POST",
        headers: { "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content, Accept: "application/json" }
      })
      data = await res.json()
      if (data.error) { this.fail(data.error); return }
    } catch (e) { this.fail("Có lỗi, thử lại sau."); return }

    const n = this.countValue
    const ang = 360 / n
    // Land the winning segment's centre under the top pointer. Compute the delta
    // from the CURRENT angle (the wheel accumulates rotation across spins, so a
    // fixed formula drifts by the previous result) + 7 full turns for effect.
    const desired = (360 - (data.index * ang + ang / 2)) % 360
    const current = ((this.rotation % 360) + 360) % 360
    const delta = (desired - current + 360) % 360
    this.rotation += delta + 360 * 7
    this.wheelTarget.style.transform = `rotate(${this.rotation}deg)`

    this.playSpinTicks(5.0)
    setTimeout(() => this.reveal(data), 5100)
  }

  reveal(data) {
    const won = data.points > 0 || data.reward
    if (data.reward)      this.resultTarget.textContent = `🎉 Trúng ${data.reward} — đã vào ví của bạn!`
    else if (data.points > 0) this.resultTarget.textContent = `🎉 ${data.label}!`
    else                  this.resultTarget.textContent = `${data.label} — chúc bạn may mắn lần sau`
    if (won) { this.confetti(); this.playWin() } else { this.playLose() }
    // Update spin state
    if (data.free_left) {
      this.btnTarget.textContent = "Quay miễn phí 🎉"
      this.hintTarget.textContent = "Bạn còn lượt quay miễn phí."
    } else {
      this.btnTarget.textContent = `Quay (${this.costValue} điểm)`
      this.hintTarget.textContent = `Số dư: ${data.balance.toLocaleString("vi-VN")} điểm.`
    }
    this.btnTarget.disabled = false
    this.spinning = false
  }

  fail(msg) {
    this.resultTarget.textContent = msg
    this.btnTarget.disabled = false
    this.spinning = false
  }

  confetti() {
    const el = document.createElement("div")
    el.dataset.controller = "pointburst"
    document.body.appendChild(el)
    setTimeout(() => el.remove(), 2000)
  }

  // ---------- Synthesized sound (Web Audio; no asset dependency) ----------
  audio() {
    try {
      if (!this.ac) this.ac = new (window.AudioContext || window.webkitAudioContext)()
      if (this.ac.state === "suspended") this.ac.resume()
      return this.ac
    } catch (e) { return null }
  }

  // Ratchet ticks that slow down over the spin, like a real wheel.
  playSpinTicks(duration) {
    const ac = this.audio(); if (!ac) return
    let t = ac.currentTime + 0.02, interval = 0.045
    const end = ac.currentTime + duration
    while (t < end) {
      this.blip(t, 1250, 0.014, 0.05)
      t += interval
      interval = Math.min(interval * 1.12, 0.32)
    }
  }

  playWin() {
    const ac = this.audio(); if (!ac) return
    [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => this.tone(ac.currentTime + i * 0.12, f, 0.2, 0.12, "sine"))
  }

  playLose() {
    const ac = this.audio(); if (!ac) return
    this.tone(ac.currentTime, 392, 0.22, 0.09, "sine")
    this.tone(ac.currentTime + 0.16, 311.13, 0.34, 0.09, "sine")
  }

  blip(when, freq, dur, vol) { this.tone(when, freq, dur, vol, "square") }

  tone(when, freq, dur, vol, type) {
    const ac = this.audio(); if (!ac) return
    const o = ac.createOscillator(), g = ac.createGain()
    o.type = type; o.frequency.value = freq
    g.gain.setValueAtTime(0.0001, when)
    g.gain.linearRampToValueAtTime(vol, when + 0.006)
    g.gain.exponentialRampToValueAtTime(0.0001, when + dur)
    o.connect(g).connect(ac.destination)
    o.start(when); o.stop(when + dur + 0.03)
  }
}
