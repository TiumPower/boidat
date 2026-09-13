import { Controller } from "@hotwired/stimulus"

// Voucher validity mode: enable only the input for the chosen option (N days
// after claim vs a fixed expiry date). Disabled inputs aren't submitted, so the
// controller reads exactly one, unambiguously.
export default class extends Controller {
  static targets = ["radio", "relativeInput", "fixedInput", "relativeRow", "fixedRow"]

  connect() { this.apply() }
  switch() { this.apply() }

  apply() {
    const mode = this.radioTargets.find((r) => r.checked)?.value || "relative"
    if (this.hasRelativeInputTarget) this.relativeInputTarget.disabled = mode !== "relative"
    if (this.hasFixedInputTarget) this.fixedInputTarget.disabled = mode !== "fixed"
    if (this.hasRelativeRowTarget) this.dim(this.relativeRowTarget, mode !== "relative")
    if (this.hasFixedRowTarget) this.dim(this.fixedRowTarget, mode !== "fixed")
  }

  // Soften the row that isn't selected — WITHOUT dimming its radio (a faded radio
  // reads as disabled). Grey the label text and fade only its input; the radio
  // stays crisp and clickable so the user can switch modes.
  dim(row, off) {
    if (!row) return
    row.style.color = off ? "var(--ink-2)" : ""
    row.querySelectorAll("input:not([type=radio]), select").forEach((el) => {
      el.style.opacity = off ? "0.5" : ""
      el.style.pointerEvents = off ? "none" : ""
    })
  }
}
