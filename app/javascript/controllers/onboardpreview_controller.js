import { Controller } from "@hotwired/stimulus"

// Onboarding palette preview: picking a preset recolors the merchant page (the
// main brand color) AND the customer-app demo card in real time, so the owner
// sees the look before committing.
export default class extends Controller {
  static targets = ["radio", "demo", "tagline", "taglineOut"]

  connect() {
    const checked = this.radioTargets.find((r) => r.checked) || this.radioTargets[0]
    if (checked) { checked.checked = true; this.paint(checked) }
  }

  apply(event) { this.paint(event.currentTarget) }

  paint(radio) {
    const d = radio.dataset
    // Merchant page: swap the primary brand color live.
    const root = document.documentElement.style
    if (d.primary)  root.setProperty("--primary", d.primary)
    if (d.primary2) root.setProperty("--primary-2", d.primary2)
    if (d.onPrimary) root.setProperty("--on-primary", d.onPrimary)

    // Customer-app demo: full theme, scoped to the demo element.
    if (this.hasDemoTarget) {
      const s = this.demoTarget.style
      const map = { "--primary": d.primary, "--primary-2": d.primary2, "--on-primary": d.onPrimary,
                    "--surface": d.surface, "--surface-2": d.surface2, "--ink": d.ink, "--ink-2": d.ink2 }
      for (const k in map) { if (map[k]) s.setProperty(k, map[k]) }
    }

    // Selected-state ring.
    this.element.querySelectorAll(".l-preset").forEach((e) => (e.style.borderColor = "var(--line)"))
    const label = radio.closest(".l-preset")
    if (label) label.style.borderColor = "var(--primary)"
  }

  syncText() {
    if (this.hasTaglineTarget && this.hasTaglineOutTarget && this.taglineTarget.value.trim()) {
      this.taglineOutTarget.textContent = this.taglineTarget.value
    }
  }
}
