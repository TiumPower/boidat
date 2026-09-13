import { Controller } from "@hotwired/stimulus"

// Quét khuôn mặt tại quầy (FR-231). Mở camera trước, chụp một khung mỗi ~1.2s
// và gửi lên service nhận diện.
//
// Nguyên tắc: service chết hoặc trình duyệt không cho camera thì màn hình phải
// tự rơi xuống ô tra cứu theo tên, không được đứng hình — quầy vẫn phải chạy
// (FR-234).
export default class extends Controller {
  static targets = ["video", "canvas", "status", "fallback"]
  static values = { url: String, interval: { type: Number, default: 1200 } }

  connect() {
    this.busy = false
    this.failures = 0
    this.start()
  }

  disconnect() {
    this.stop()
  }

  async start() {
    if (!navigator.mediaDevices?.getUserMedia) {
      return this.degrade("Trình duyệt không hỗ trợ camera — tra cứu theo tên bên dưới.")
    }
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "user", width: { ideal: 720 }, height: { ideal: 720 } },
        audio: false,
      })
      this.videoTarget.srcObject = this.stream
      await this.videoTarget.play()
      this.setStatus("Đưa khuôn mặt vào khung")
      this.timer = setInterval(() => this.tick(), this.intervalValue)
    } catch (error) {
      this.degrade("Chưa cấp quyền camera — tra cứu theo tên bên dưới.")
    }
  }

  stop() {
    if (this.timer) clearInterval(this.timer)
    if (this.stream) this.stream.getTracks().forEach((t) => t.stop())
  }

  async tick() {
    if (this.busy || this.videoTarget.readyState < 2) return
    this.busy = true
    try {
      const image = this.snapshot()
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": this.csrf() },
        body: JSON.stringify({ image }),
      })
      const data = await response.json()

      if (data.ok && data.redirect) {
        this.stop()
        window.location = data.redirect
        return
      }
      this.failures += 1
      // Ba lần trượt liên tiếp là đủ để lễ tân nhận ra nên chuyển cách khác —
      // đúng con số trong bản thiết kế UX.
      if (data.fallback || this.failures >= 3) {
        this.degrade(data.error || "Không nhận ra khuôn mặt sau 3 lần thử.")
      } else {
        this.setStatus(data.error || "Đang tìm…")
      }
    } catch (error) {
      this.degrade("Mất kết nối tới máy chủ nhận diện — tra cứu theo tên bên dưới.")
    } finally {
      this.busy = false
    }
  }

  snapshot() {
    const video = this.videoTarget
    const canvas = this.canvasTarget
    const size = 480
    canvas.width = size
    canvas.height = size
    const ctx = canvas.getContext("2d")
    // Cắt vuông giữa khung: khuôn mặt người đứng quét luôn ở chính giữa.
    const side = Math.min(video.videoWidth, video.videoHeight)
    const sx = (video.videoWidth - side) / 2
    const sy = (video.videoHeight - side) / 2
    ctx.drawImage(video, sx, sy, side, side, 0, 0, size, size)
    return canvas.toDataURL("image/jpeg", 0.85)
  }

  degrade(message) {
    this.stop()
    this.setStatus(message)
    if (this.hasFallbackTarget) this.fallbackTarget.hidden = false
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }

  csrf() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}
