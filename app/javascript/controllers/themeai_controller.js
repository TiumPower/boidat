import { Controller } from "@hotwired/stimulus"

// "Suggest colours from logo" button. POSTs to the server (which calls Claude
// vision on the uploaded logo), then fills the colour pickers and dispatches
// input events so the existing theme-preview controller updates live. Nothing
// is saved until the merchant clicks Save.
export default class extends Controller {
  static targets = ["button"]
  static values = { url: String }

  // Reveal the AI palette button the moment a logo file is picked.
  logoPicked(event) {
    if (this.hasButtonTarget && event.target.files && event.target.files.length) {
      this.buttonTarget.hidden = false
    }
  }

  async suggest(event) {
    const btn = event.currentTarget
    const original = btn.textContent
    btn.disabled = true
    btn.textContent = "⏳ Đang phân tích logo…"

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const resp = await fetch(this.urlValue, {
        method: "POST",
        headers: { "X-CSRF-Token": token, "Accept": "application/json" }
      })
      const data = await resp.json()
      if (!resp.ok || !data.ok) {
        alert(this.errorMessage(data.error))
        return
      }
      Object.entries(data.theme).forEach(([key, hex]) => {
        const input = document.querySelector(`input[name="theme[${key}]"]`)
        if (input) {
          input.value = hex
          input.dispatchEvent(new Event("input", { bubbles: true }))
        }
      })
    } catch (e) {
      alert("Có lỗi khi gọi AI. Vui lòng thử lại.")
    } finally {
      btn.disabled = false
      btn.textContent = original
    }
  }

  errorMessage(code) {
    if (code === "no_logo") return "Hãy tải logo lên và lưu trước khi để AI gợi ý màu."
    if (code === "not_configured") return "AI chưa được cấu hình (thiếu API key)."
    return "Không tạo được bảng màu. Vui lòng thử lại."
  }
}
