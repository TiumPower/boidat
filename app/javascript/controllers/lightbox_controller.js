import { Controller } from "@hotwired/stimulus"

// In-app full-screen viewer for uploaded documents/photos. Opens without any
// navigation (so a tap never leaves the page), lets you swipe / arrow between
// every item on the page, and offers download + close.
export default class extends Controller {
  static targets = ["item", "overlay", "stage", "name", "download", "count", "prev", "next"]

  open(e) {
    e.preventDefault()
    this.index = this.itemTargets.indexOf(e.currentTarget)
    if (this.index < 0) this.index = 0
    this.render()
    this.overlayTarget.hidden = false
    document.body.style.overflow = "hidden"
  }

  render() {
    const el = this.itemTargets[this.index]
    if (!el) return
    const { lbUrl, lbDownload, lbName, lbType } = el.dataset
    this.nameTarget.textContent = lbName || ""
    this.downloadTarget.href = lbDownload || lbUrl
    this.downloadTarget.setAttribute("download", lbName || "")
    this.stageTarget.innerHTML = ""

    if (lbType === "image") {
      const img = document.createElement("img")
      img.src = lbUrl
      img.className = "ce-lb-img"
      img.alt = lbName || ""
      this.stageTarget.appendChild(img)
    } else if (lbType === "pdf") {
      const frame = document.createElement("iframe")
      frame.src = lbUrl
      frame.className = "ce-lb-frame"
      this.stageTarget.appendChild(frame)
    } else {
      const box = document.createElement("div")
      box.className = "ce-lb-file"
      box.innerHTML =
        `<div class="ce-lb-file-ic">📄</div><div class="ce-lb-file-nm"></div>` +
        `<div class="ce-lb-file-hint">Bấm “Tải xuống” để mở tệp này.</div>`
      box.querySelector(".ce-lb-file-nm").textContent = lbName || "Tài liệu"
      this.stageTarget.appendChild(box)
    }

    const many = this.itemTargets.length > 1
    this.prevTarget.hidden = !many
    this.nextTarget.hidden = !many
    this.countTarget.hidden = !many
    if (many) this.countTarget.textContent = `${this.index + 1} / ${this.itemTargets.length}`
  }

  next() { this.index = (this.index + 1) % this.itemTargets.length; this.render() }
  prev() { this.index = (this.index - 1 + this.itemTargets.length) % this.itemTargets.length; this.render() }

  close() {
    this.overlayTarget.hidden = true
    this.stageTarget.innerHTML = ""
    document.body.style.overflow = ""
  }

  backdrop(e) { if (e.target === this.overlayTarget || e.target === this.stageTarget) this.close() }

  // Swipe left/right on touch devices
  touchStart(e) { this._x = e.changedTouches[0].clientX }
  touchEnd(e) {
    const dx = e.changedTouches[0].clientX - (this._x ?? 0)
    if (Math.abs(dx) > 45 && this.itemTargets.length > 1) { dx < 0 ? this.next() : this.prev() }
  }

  connect() {
    this._keys = (e) => {
      if (this.overlayTarget.hidden) return
      if (e.key === "Escape") this.close()
      else if (e.key === "ArrowRight") this.next()
      else if (e.key === "ArrowLeft") this.prev()
    }
    document.addEventListener("keydown", this._keys)
  }

  disconnect() {
    document.removeEventListener("keydown", this._keys)
    document.body.style.overflow = ""
  }
}
