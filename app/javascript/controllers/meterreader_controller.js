import { Controller } from "@hotwired/stimulus"

// Reads a meter photo with AI and fills the reading field, and keeps the
// tenant oriented: last recorded number, live consumption, and a warning when
// the period already has a reading.
export default class extends Controller {
  static targets = ["file", "reading", "status", "preview", "kind",
                    "prevBox", "prevVal", "useBox", "useVal", "dupBox"]
  static values = { url: String, kind: String }

  connect() { this.kindChanged() }

  choose() { this.fileTarget.click() }

  // The kind select drives which meter the AI is asked to read. This used to be
  // frozen at render time, so choosing Nước still sent kind=electricity.
  kindChanged() {
    if (this.hasKindTarget) this.kindValue = this.kindTarget.value
    this.#renderContext()
    this.recalc()
  }

  recalc() {
    const prev = this.#previous()
    const curr = parseFloat(this.readingTarget?.value)
    if (!this.hasUseBoxTarget) return
    if (prev == null || isNaN(curr)) { this.useBoxTarget.hidden = true; return }
    const used = curr - prev
    this.useBoxTarget.hidden = false
    this.useValTarget.textContent = used.toLocaleString("vi-VN")
    // A number below last month's is a typo or a rolled-over meter — flag it
    // rather than letting it through into a bill.
    this.useValTarget.classList.toggle("neg", used < 0)
  }

  async changed() {
    const file = this.fileTarget.files[0]
    if (!file) return
    if (this.hasPreviewTarget) {
      this.previewTarget.src = URL.createObjectURL(file)
      this.previewTarget.hidden = false
    }
    this.setStatus("⏳ AI đang đọc chỉ số…", "var(--ink-2)")

    const body = new FormData()
    body.append("photo", file)
    body.append("kind", this.kindValue || "electricity")
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const res = await fetch(this.urlValue, { method: "POST", body, headers: { "X-CSRF-Token": token } })
      const data = await res.json()
      if (data.ok && data.reading != null) {
        this.readingTarget.value = data.reading
        const conf = data.confidence === "high" ? "✓" : "⚠ (hãy kiểm tra lại)"
        this.setStatus(`AI đọc được: ${data.reading} ${conf}`, data.confidence === "high" ? "#1a7f5a" : "#b8860b")
        this.recalc()
      } else {
        this.setStatus("Không đọc được tự động — vui lòng nhập tay.", "#b8860b")
      }
    } catch (e) {
      this.setStatus("Lỗi kết nối — vui lòng nhập tay.", "#a11")
    }
  }

  setStatus(text, color) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = text
    this.statusTarget.style.color = color
  }

  // ---- helpers ----------------------------------------------------------
  #json(name) {
    try { return JSON.parse(this.kindTarget?.dataset[name] || "{}") } catch { return {} }
  }

  #previous() {
    const v = this.#json("prev")[this.kindValue]
    return v == null ? null : parseFloat(v)
  }

  #renderContext() {
    const prev = this.#previous()
    if (this.hasPrevBoxTarget) {
      this.prevBoxTarget.hidden = prev == null
      if (prev != null) this.prevValTarget.textContent = prev.toLocaleString("vi-VN")
    }
    if (this.hasDupBoxTarget) {
      this.dupBoxTarget.hidden = !this.#json("dup")[this.kindValue]
    }
  }
}
