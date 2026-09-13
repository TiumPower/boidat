import { Controller } from "@hotwired/stimulus"

// Chữ ký vẽ tay trên canvas (FR-207). Xuất ra data URL PNG để server nhúng vào
// PDF. Hỗ trợ cả chuột lẫn cảm ứng — sale ký trên laptop, phụ huynh ký trên
// điện thoại, cùng một màn hình.
export default class extends Controller {
  static targets = ["pad", "field"]

  connect() {
    this.padTargets.forEach((canvas) => this.setup(canvas))
  }

  setup(canvas) {
    // Canvas phải khớp devicePixelRatio, nếu không nét vẽ sẽ mờ và lệch vị trí.
    const ratio = window.devicePixelRatio || 1
    const rect = canvas.getBoundingClientRect()
    canvas.width = rect.width * ratio
    canvas.height = rect.height * ratio
    const ctx = canvas.getContext("2d")
    ctx.scale(ratio, ratio)
    ctx.lineWidth = 2
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    ctx.strokeStyle = "#0C2229"

    let drawing = false
    const pos = (event) => {
      const r = canvas.getBoundingClientRect()
      const point = event.touches ? event.touches[0] : event
      return { x: point.clientX - r.left, y: point.clientY - r.top }
    }
    const start = (event) => {
      event.preventDefault()
      drawing = true
      const { x, y } = pos(event)
      ctx.beginPath()
      ctx.moveTo(x, y)
    }
    const move = (event) => {
      if (!drawing) return
      event.preventDefault()
      const { x, y } = pos(event)
      ctx.lineTo(x, y)
      ctx.stroke()
    }
    const end = () => {
      if (!drawing) return
      drawing = false
      this.save(canvas)
    }

    canvas.addEventListener("mousedown", start)
    canvas.addEventListener("mousemove", move)
    window.addEventListener("mouseup", end)
    canvas.addEventListener("touchstart", start, { passive: false })
    canvas.addEventListener("touchmove", move, { passive: false })
    canvas.addEventListener("touchend", end)
  }

  save(canvas) {
    const field = this.fieldTargets.find((f) => f.dataset.kind === canvas.dataset.kind)
    if (field) field.value = canvas.toDataURL("image/png")
  }

  clear(event) {
    const kind = event.currentTarget.dataset.kind
    const canvas = this.padTargets.find((c) => c.dataset.kind === kind)
    if (!canvas) return
    canvas.getContext("2d").clearRect(0, 0, canvas.width, canvas.height)
    const field = this.fieldTargets.find((f) => f.dataset.kind === kind)
    if (field) field.value = ""
  }
}
