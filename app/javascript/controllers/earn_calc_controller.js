import { Controller } from "@hotwired/stimulus"

// Live-previews points earned as the cashier types the bill amount.
export default class extends Controller {
  static targets = ["amount", "preview"]
  static values = { points: Number, per: Number, mult: Number }

  preview() {
    const amount = parseInt(this.amountTarget.value.replace(/[^\d]/g, ""), 10) || 0
    const base = Math.floor((amount / this.perValue) * this.pointsValue)
    const total = Math.floor(base * (this.multValue || 1))
    this.previewTarget.textContent = total.toLocaleString("vi-VN")
  }
}
