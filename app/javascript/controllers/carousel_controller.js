import { Controller } from "@hotwired/stimulus"

// Adds pagination dots under a horizontal scroll track so users know they can
// scroll for more. Dots ≈ number of viewport-pages; click a dot to jump.
export default class extends Controller {
  static targets = ["track", "dots"]

  connect() {
    this.onScroll = () => this.update()
    this.trackTarget.addEventListener("scroll", this.onScroll, { passive: true })
    this.render()
    this.resizeObserver = new ResizeObserver(() => this.render())
    this.resizeObserver.observe(this.trackTarget)
  }

  disconnect() {
    this.trackTarget.removeEventListener("scroll", this.onScroll)
    this.resizeObserver?.disconnect()
  }

  pages() {
    const w = this.trackTarget.clientWidth
    if (!w) return 1
    // Any horizontal overflow (>4px) means there is more to scroll → show dots.
    return this.trackTarget.scrollWidth - w > 4 ? Math.ceil(this.trackTarget.scrollWidth / w) : 1
  }

  render() {
    const n = this.pages()
    if (n <= 1) { this.dotsTarget.style.display = "none"; this.dotsTarget.innerHTML = ""; return }
    this.dotsTarget.style.display = "flex"
    this.dotsTarget.innerHTML = ""
    for (let i = 0; i < n; i++) {
      const d = document.createElement("button")
      d.className = "l-dot"
      d.type = "button"
      d.addEventListener("click", () => this.go(i))
      this.dotsTarget.appendChild(d)
    }
    this.update()
  }

  maxScroll() { return this.trackTarget.scrollWidth - this.trackTarget.clientWidth }

  go(i) {
    const n = this.dotsTarget.children.length
    const left = n > 1 ? (i / (n - 1)) * this.maxScroll() : 0
    this.trackTarget.scrollTo({ left, behavior: "smooth" })
  }

  // Map scroll position across the full range onto dot indices so the LAST dot
  // activates at the end of the swipe (fixes coarse clientWidth-based rounding).
  update() {
    const n = this.dotsTarget.children.length
    const max = this.maxScroll()
    const i = max > 4 ? Math.round((this.trackTarget.scrollLeft / max) * (n - 1)) : 0
    Array.from(this.dotsTarget.children).forEach((d, j) => d.classList.toggle("active", j === i))
  }
}
