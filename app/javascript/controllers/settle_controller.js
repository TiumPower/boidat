import { Controller } from "@hotwired/stimulus"

// Live deposit maths while the landlord fills in deductions, so the refund is
// visible before committing. A shortfall (deductions exceed the deposit) is
// reported explicitly rather than silently clamped to zero.
export default class extends Controller {
  static targets = ["deductOut", "unpaidOut", "unpaidRow", "resultOut", "resultLabel",
                    "resultBox", "refunded", "offsetUnpaid"]

  connect() {
    this.box = this.element.querySelector("[data-settle-deposit-value]")
    this.deposit = parseInt(this.box?.dataset.settleDepositValue || "0", 10)
    this.unpaid = parseInt(this.box?.dataset.settleUnpaidValue || "0", 10)
    // Recalculate on any input in the form, since deduction rows are added dynamically.
    this.element.addEventListener("input", () => this.recalc())
    this.element.addEventListener("change", () => this.recalc())
    this.recalc()
  }

  recalc() {
    const deducted = [...this.element.querySelectorAll("input[name$='[amount]']")]
      .reduce((sum, i) => sum + (parseInt(i.value, 10) || 0), 0)

    const offset = this.hasOffsetUnpaidTarget ? this.offsetUnpaidTarget.checked : false
    const unpaid = offset ? this.unpaid : 0
    const total = deducted + unpaid
    const refund = Math.max(this.deposit - total, 0)
    const short = Math.max(total - this.deposit, 0)

    if (this.hasDeductOutTarget) this.deductOutTarget.textContent = this.#vnd(deducted)
    if (this.hasUnpaidOutTarget) this.unpaidOutTarget.textContent = this.#vnd(unpaid)
    if (this.hasUnpaidRowTarget) this.unpaidRowTarget.style.opacity = offset ? "1" : ".4"

    if (short > 0) {
      this.resultLabelTarget.textContent = "Người thuê còn thiếu"
      this.resultOutTarget.textContent = this.#vnd(short)
      this.resultBoxTarget.style.background = "color-mix(in srgb, #e5484d 10%, #fff)"
      this.resultOutTarget.style.color = "#e5484d"
    } else {
      this.resultLabelTarget.textContent = "Hoàn lại cho người thuê"
      this.resultOutTarget.textContent = this.#vnd(refund)
      this.resultBoxTarget.style.background = "color-mix(in srgb, #1a7f5a 9%, #fff)"
      this.resultOutTarget.style.color = "#1a7f5a"
    }

    // Mirror into the editable field only while the landlord hasn't typed there.
    if (this.hasRefundedTarget && !this.refundedTarget.dataset.touched) {
      this.refundedTarget.placeholder = `${refund.toLocaleString("vi-VN")} (tự tính)`
    }
  }

  markTouched(e) { e.target.dataset.touched = "1" }

  #vnd(n) { return `${(n || 0).toLocaleString("vi-VN")}đ` }
}
