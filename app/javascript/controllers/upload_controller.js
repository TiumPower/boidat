import { Controller } from "@hotwired/stimulus"

// Ô chọn tệp. Nút mặc định của trình duyệt in "Choose File / No file chosen"
// bằng tiếng Anh và không đổi được bằng CSS — trên màn gửi ảnh khuôn mặt của
// phụ huynh thì đó là chuỗi tiếng Anh duy nhất của cả app. Ở đây input bị ẩn,
// nhãn do mình vẽ, và tên tệp đã chọn được ghi lại để phụ huynh biết là đã chọn.
export default class extends Controller {
  static targets = ["input", "name"]
  static values = { placeholder: String }

  connect() { this.render() }

  render() {
    const file = this.inputTarget.files && this.inputTarget.files[0]
    this.nameTarget.textContent = file ? file.name : this.placeholderValue
    this.element.classList.toggle("has-file", Boolean(file))
  }
}
