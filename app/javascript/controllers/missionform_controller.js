import { Controller } from "@hotwired/stimulus"

// Toggles mission-form fields by type. Photo-proof missions (review /
// social_share) are single-submission (goal forced to 1, goal field hidden,
// period locked to one-time); social_share also reveals the per-platform block.
export default class extends Controller {
  static targets = ["type", "goalWrap", "platforms", "period"]

  connect() { this.typeChanged() }

  typeChanged() {
    const t = this.typeTarget.value
    const photoProof = t === "review" || t === "social_share"

    if (this.hasGoalWrapTarget) {
      this.goalWrapTarget.hidden = photoProof
      const goal = this.goalWrapTarget.querySelector("input")
      if (goal && photoProof) goal.value = 1
    }
    if (this.hasPlatformsTarget) {
      this.platformsTarget.hidden = t !== "social_share"
    }
    // Photo-proof = one-time only; lock the period to "once" and disable it.
    // (The server also forces this, so a disabled/unsubmitted select is fine.)
    if (this.hasPeriodTarget) {
      if (photoProof) { this.periodTarget.value = "once"; this.periodTarget.disabled = true }
      else { this.periodTarget.disabled = false; if (this.periodTarget.value === "once") this.periodTarget.value = "daily" }
    }
  }
}
