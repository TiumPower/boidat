import { Controller } from "@hotwired/stimulus"

// Live consumption (new − previous) per row while the landlord types, so a
// mistyped digit is obvious before saving 30 rooms at once.
export default class extends Controller {
  static targets = ["row"]

  connect() { this.rowTargets.forEach((row) => this.#update(row)) }

  recalc(e) { this.#update(e.target.closest("[data-meterbatch-target='row']")) }

  #update(row) {
    if (!row) return
    const prev = parseFloat(row.querySelector("[data-meterbatch-target='prev']")?.dataset.prev)
    const curr = parseFloat(row.querySelector("[data-meterbatch-target='input']")?.value)
    const out = row.querySelector("[data-meterbatch-target='use']")
    if (!out) return

    if (isNaN(curr)) { out.textContent = "—"; out.classList.remove("neg"); return }
    if (isNaN(prev)) { out.textContent = "—"; out.classList.remove("neg"); return }
    const used = curr - prev
    out.textContent = used.toLocaleString("vi-VN")
    // A negative delta means the new number is below the old one — a typo, or
    // the meter rolled over. Flag it rather than silently billing nonsense.
    out.classList.toggle("neg", used < 0)
  }
}
