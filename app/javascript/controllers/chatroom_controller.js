import { Controller } from "@hotwired/stimulus"

// Khung chat (FR-224 hộp thư admin, FR-407 chat phụ huynh).
//
// Controller gắn thẳng lên khung cuộn, nên KHÔNG khai target nào. Bản trước
// bê nguyên từ Estate: nó khai sáu target và gọi `this.scrollTarget` ngay
// trong connect(), mà view lại không khai target nào — Stimulus ném lỗi ở
// connect nên toàn bộ controller chết. Hệ quả là chat không tự cuộn, không
// nhận tin mới khi WebSocket hỏng, và lỗi đỏ hiện trên console mọi lần mở.
// Ai cầm target là chuyện của view, nên cách chắc chắn nhất là đừng cần target.
//
// Việc căn trái/phải "tin của tôi" do server làm trong shared/_message
// (`sender_kind == viewer`), không phải việc của JS.
export default class extends Controller {
  static values = { updatesUrl: String }

  connect() {
    // Vào thẳng tin mới nhất, không để người dùng thấy cú nhảy: giấu danh sách
    // cho tới khi đã cuộn xong ở khung hình kế tiếp.
    this.element.style.visibility = "hidden"
    this.scrollToBottom()
    requestAnimationFrame(() => {
      this.scrollToBottom()
      this.element.style.visibility = ""
    })
    // Ảnh tải xong làm đổi chiều cao — ghim lại đáy.
    this.element.querySelectorAll("img").forEach((img) => {
      if (!img.complete) img.addEventListener("load", () => this.scrollToBottom(), { once: true })
    })
    this.observer = new MutationObserver(() => { this.dedupe(); this.scrollToBottom() })
    this.observer.observe(this.element, { childList: true })
    this.startPolling()
  }

  disconnect() {
    this.observer?.disconnect()
    if (this.poll) clearInterval(this.poll)
  }

  // Dự phòng khi WebSocket /cable không dùng được (proxy không upgrade chẳng
  // hạn): hỏi tin mới hơn tin cuối cùng đang có. Tự tắt khi cable đang sống,
  // nên lúc WebSocket chạy tốt thì nó không tốn gì.
  startPolling() {
    if (!this.hasUpdatesUrlValue || !this.updatesUrlValue) return
    this.poll = setInterval(() => this.pollOnce(), 5000)
  }

  pollOnce() {
    const src = document.querySelector("turbo-cable-stream-source")
    if (src && src.hasAttribute("connected")) return
    if (document.hidden) return
    fetch(`${this.updatesUrlValue}?after=${this.lastId()}`, {
      headers: { Accept: "text/vnd.turbo-stream.html" }, credentials: "same-origin"
    })
      .then((r) => (r.ok ? r.text() : ""))
      .then((html) => { if (html && html.trim()) window.Turbo.renderStreamMessage(html) })
      .catch(() => {})
  }

  lastId() {
    const ids = Array.from(this.element.querySelectorAll("[id^='message_']"))
      .map((e) => parseInt(e.id.replace("message_", ""), 10) || 0)
    return ids.length ? Math.max(...ids) : 0
  }

  // Người gửi nhận tin của chính mình hai lần: một từ phản hồi POST, một từ
  // bản tin broadcast. Giữ lại node đầu tiên của mỗi id.
  dedupe() {
    const seen = new Set()
    this.element.querySelectorAll("[id^='message_']").forEach((el) => {
      if (seen.has(el.id)) el.remove()
      else seen.add(el.id)
    })
  }

  scrollToBottom() {
    this.element.scrollTop = this.element.scrollHeight
  }
}
