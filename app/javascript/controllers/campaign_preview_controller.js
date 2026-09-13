import { Controller } from "@hotwired/stimulus"

// Mirrors the campaign builder inputs into the live customer-notification preview.
export default class extends Controller {
  static targets = ["title", "body", "reward", "pvTitle", "pvBody", "pvReward"]

  connect() { this.update() }

  update() {
    if (this.hasTitleTarget) this.pvTitleTarget.textContent = this.titleTarget.value || "Tiêu đề ưu đãi"
    if (this.hasBodyTarget) this.pvBodyTarget.textContent = this.bodyTarget.value || "Mô tả ngắn hiển thị ở đây…"
    if (this.hasRewardTarget) {
      const opt = this.rewardTarget.selectedOptions[0]
      this.pvRewardTarget.innerHTML = opt && opt.value
        ? `<span class="l-chip l-chip-brand">${opt.textContent}</span>` : ""
    }
  }
}
