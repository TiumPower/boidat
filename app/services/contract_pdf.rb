require "prawn"
require "prawn/table"

# Sinh bản cam kết PDF từ template có điền sẵn thông tin (FR-207).
#
# Dùng Prawn thay vì headless Chrome: thuần Ruby, không cần binary ngoài, chạy
# được trên VPS nhỏ. Font Be Vietnam Pro được nhúng để tiếng Việt có dấu hiển
# thị đúng — Helvetica mặc định của Prawn không có glyph tiếng Việt.
class ContractPdf
  FONT_DIR = Rails.root.join("app/assets/fonts")

  def initialize(contract)
    @contract = contract
    @enrollment = contract.enrollment
    @student = contract.student
    @swim_class = @enrollment.swim_class
    @workspace = contract.workspace
    @pool = contract.pool
  end

  def render
    pdf = Prawn::Document.new(page_size: "A4", margin: [40, 45, 45, 45])
    setup_font(pdf)

    header(pdf)
    parties(pdf)
    details(pdf)
    terms(pdf)
    signatures(pdf)
    footer(pdf)

    pdf.render
  end

  private

  # Nhúng font tiếng Việt nếu có; nếu chưa cài font thì vẫn sinh được file bằng
  # Helvetica (mất dấu) chứ không làm hỏng cả luồng ký cam kết.
  def setup_font(pdf)
    regular = FONT_DIR.join("BeVietnamPro-Regular.ttf")
    bold    = FONT_DIR.join("BeVietnamPro-Bold.ttf")
    return unless File.exist?(regular) && File.exist?(bold)

    pdf.font_families.update("BeVietnam" => { normal: regular.to_s, bold: bold.to_s })
    pdf.font "BeVietnam"
  rescue StandardError => e
    Rails.logger.warn("[contract] không nạp được font: #{e.message}")
  end

  def header(pdf)
    pdf.text @workspace.name.to_s.upcase, size: 11, align: :center
    pdf.text "CỘNG HOÀ XÃ HỘI CHỦ NGHĨA VIỆT NAM", size: 10, align: :center
    pdf.text "Độc lập – Tự do – Hạnh phúc", size: 10, align: :center, style: :bold
    pdf.move_down 18
    pdf.text "BẢN CAM KẾT THAM GIA KHOÁ HỌC BƠI", size: 15, align: :center, style: :bold
    pdf.text "Số: #{@contract.number}", size: 10, align: :center
    pdf.move_down 16
  end

  def parties(pdf)
    pdf.text "BÊN A — TRUNG TÂM", size: 11, style: :bold
    pdf.text "#{@workspace.name} · #{@pool.name}", size: 10
    pdf.text "Địa chỉ: #{@pool.address}", size: 10 if @pool.address.present?
    pdf.text "Điện thoại: #{@pool.phone.presence || @workspace.contact_phone}", size: 10
    pdf.move_down 10

    pdf.text "BÊN B — PHỤ HUYNH / HỌC VIÊN", size: 11, style: :bold
    pdf.text "Người đại diện: #{@contract.guardian_name}", size: 10
    guardian = @contract.household.owner
    pdf.text "Điện thoại: #{guardian&.phone}", size: 10
    pdf.move_down 14
  end

  def details(pdf)
    rows = [
      ["Học viên", @student.name],
      ["Ngày sinh", @student.birthdate ? I18n.l(@student.birthdate, format: "%d/%m/%Y") : "—"],
      ["Khoá học", @swim_class.course&.name || "—"],
      ["Loại lớp", "1:#{@swim_class.class_type}"],
      ["Giáo viên", @swim_class.teacher.display_name],
      ["Lịch học", "#{@swim_class.slot_label} tại #{@pool.name}"],
      ["Số buổi", "#{@enrollment.total_available} buổi"],
      ["Ngày bắt đầu", @enrollment.starts_on ? I18n.l(@enrollment.starts_on, format: "%d/%m/%Y") : "—"],
      ["Hạn sử dụng", @enrollment.expires_on ? I18n.l(@enrollment.expires_on, format: "%d/%m/%Y") : "—"],
      ["Học phí", money(@enrollment.order&.total)]
    ]
    pdf.table(rows, width: pdf.bounds.width, cell_style: { size: 10, padding: [5, 7], borders: [:bottom],
                                                           border_color: "DDDDDD" }) do
      column(0).width = 130
      column(0).font_style = :bold
    end
    pdf.move_down 14
  end

  def terms(pdf)
    pdf.text "ĐIỀU KHOẢN", size: 11, style: :bold
    pdf.move_down 4
    items = [
      "Một buổi học kéo dài 60 phút. Học viên có mặt tại quầy và điểm danh trước khi xuống nước.",
      "Gói học có hạn sử dụng #{@enrollment.expires_on ? I18n.l(@enrollment.expires_on, format: '%d/%m/%Y') : 'theo quy định'}; " \
        "hết hạn thì số buổi chưa dùng không còn hiệu lực.",
      "Học viên nghỉ không báo trước sẽ không bị trừ buổi, nhưng lớp vẫn giữ chỗ. " \
        "Muốn đổi lịch, phụ huynh dùng tính năng đổi buổi trên ứng dụng.",
      "Buổi học bị huỷ do giáo viên nghỉ sẽ không trừ buổi của học viên; trung tâm sắp xếp lịch bù.",
      "Học viên chỉ học tại cơ sở đã đăng ký (#{@pool.name}).",
      "Trung tâm xử lý ảnh khuôn mặt của học viên để phục vụ điểm danh, theo Nghị định 13/2023/NĐ-CP. " \
        "Phụ huynh có quyền yêu cầu xoá dữ liệu này bất kỳ lúc nào."
    ]
    items.each_with_index do |text, i|
      pdf.text "#{i + 1}. #{text}", size: 9.5, leading: 2
      pdf.move_down 3
    end
    pdf.move_down 12
  end

  def signatures(pdf)
    pdf.text "Hai bên đã đọc, hiểu rõ và đồng ý với toàn bộ nội dung trên.", size: 9.5
    pdf.move_down 14
    y = pdf.cursor
    half = pdf.bounds.width / 2

    pdf.bounding_box([0, y], width: half - 10, height: 120) do
      pdf.text "ĐẠI DIỆN TRUNG TÂM", size: 10, style: :bold, align: :center
      draw_signature(pdf, @contract.center_signature)
    end
    pdf.bounding_box([half + 10, y], width: half - 10, height: 120) do
      pdf.text "PHỤ HUYNH / HỌC VIÊN", size: 10, style: :bold, align: :center
      draw_signature(pdf, @contract.guardian_signature)
      pdf.text @contract.guardian_name.to_s, size: 10, align: :center
    end
  end

  def draw_signature(pdf, attachment)
    pdf.move_down 6
    if attachment&.attached?
      pdf.image StringIO.new(attachment.download), fit: [180, 60], position: :center
    else
      pdf.move_down 46
    end
    pdf.stroke_horizontal_rule
    pdf.move_down 4
  rescue StandardError
    pdf.move_down 46
    pdf.stroke_horizontal_rule
  end

  def footer(pdf)
    pdf.move_down 20
    pdf.text "Ký điện tử lúc #{I18n.l(Time.current, format: '%H:%M %d/%m/%Y')}. " \
             "Chữ ký vẽ tay trên màn hình là bằng chứng điện tử, không phải chữ ký số " \
             "theo Luật Giao dịch điện tử.", size: 8, color: "777777"
  end

  def money(amount)
    return "—" if amount.nil?
    "#{ActiveSupport::NumberHelper.number_to_delimited(amount.to_i)}đ"
  end
end
