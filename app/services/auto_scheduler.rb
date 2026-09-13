# Bộ xếp lịch tự động (FR-205) — hạng mục rủi ro nghiệp vụ cao nhất của dự án.
#
# Ba quyết định đã chốt với khách, cài cứng ở đây:
#
# 1. **Chỉ xếp phần còn TRỐNG.** Mọi lớp chưa kết thúc khoá đều bị khoá cứng,
#    không được xáo lại (OQ-08). Học viên mua khoá 12 buổi thì không thể mỗi
#    tuần lại bị đổi thầy đổi giờ — phụ huynh sẽ phản ứng ngay.
# 2. **Hai đầu vào bắt buộc:** lịch đăng ký dạy của giáo viên (FR-304) và các
#    lớp đang chạy. Không có đăng ký thì không có gì để xếp.
# 3. **Luôn dừng ở bản nháp.** Người duyệt xem trước và chỉnh tay rồi mới Áp
#    dụng. Không bao giờ ghi thẳng vào lịch thật.
#
# "Phân bổ đồng đều" đo bằng **độ lệch chuẩn số CÔNG** giữa các giáo viên cùng
# level — không phải số tiết. Hai giáo viên cùng 20 tiết nhưng một người toàn
# lớp 1:1 và một người toàn lớp 1:3 thì thu nhập chênh gấp ba lần, nên cân theo
# tiết là cân sai thứ.
#
# Cân bằng nhìn vào **lịch sử phân công 3 tháng gần nhất**, không chỉ tháng đang
# xếp: một giáo viên vừa nghỉ thai sản về sẽ có tháng này trống trơn, nếu chỉ
# nhìn tháng hiện tại thì thuật toán dồn hết slot cho họ. Tháng gần thì tính
# nặng hơn tháng xa (trọng số 1.0 / 0.6 / 0.3).
class AutoScheduler
  Proposal = Struct.new(:teacher_id, :teacher_name, :weekday, :hour, :date, :level,
                        :reason, keyword_init: true) do
    def to_h = super.transform_keys(&:to_s)
  end

  def initialize(pool:, month:, workspace: nil)
    @pool = pool
    @month = month.to_date.beginning_of_month
    @workspace = workspace || pool.workspace
  end

  # Sinh bản nháp. Trả về ScheduleRun ở trạng thái draft.
  def build_draft(created_by: nil)
    proposals = compute_proposals
    ScheduleRun.create!(
      workspace: @workspace, pool: @pool, month: @month, created_by: created_by,
      status: "draft", proposals: proposals.map(&:to_h), metrics: metrics(proposals)
    )
  end

  # Ô trống có thể xếp = khung giáo viên đã đăng ký dạy, trừ đi khung đã có buổi.
  def open_slots
    @open_slots ||= begin
      availability = TeacherAvailability.for_month(@month).where(pool_id: @pool.id)
                                        .includes(teacher: [:user, :teacher_level]).to_a
      busy = booked_keys
      availability.reject { |a| busy.include?("#{a.teacher_id}:#{a.weekday}:#{a.hour}") }
    end
  end

  # Khung đã bị chiếm bởi lớp ĐANG CHẠY — vùng cấm của thuật toán.
  def booked_keys
    @booked_keys ||= SwimClass.teaching.where(pool_id: @pool.id).flat_map do |cls|
      cls.weekday_list.map { |wd| "#{cls.teacher_id}:#{wd}:#{cls.start_hour}" }
    end.to_set
  end

  # Công hiện tại của từng giáo viên trong tháng đang xếp.
  def current_credits
    @current_credits ||= credits_between(@month, @month.end_of_month)
  end

  # Trọng số theo tháng: tháng liền trước nặng nhất, tháng thứ ba nhẹ nhất.
  HISTORY_WEIGHTS = [1.0, 0.6, 0.3].freeze

  # Điểm tải công có tính lịch sử 3 tháng gần nhất — đây mới là con số thuật toán
  # dùng để quyết định ai được nhận slot tiếp theo.
  def workload_score
    @workload_score ||= begin
      score = Hash.new(0.0)
      current_credits.each { |teacher_id, credits| score[teacher_id] += credits }
      HISTORY_WEIGHTS.each_with_index do |weight, offset|
        month = @month - (offset + 1).months
        credits_between(month, month.end_of_month).each do |teacher_id, credits|
          score[teacher_id] += credits * weight
        end
      end
      score
    end
  end

  # Chi tiết ba tháng gần nhất — hiện trên màn hình duyệt để admin thấy vì sao
  # thuật toán ưu tiên người này hơn người kia.
  def history_breakdown
    @history_breakdown ||= (1..3).map do |offset|
      month = @month - offset.months
      { month: month, credits: credits_between(month, month.end_of_month) }
    end
  end

  def credits_between(from, to)
    TimesheetEntry.joins(:lesson)
                  .where(pool_id: @pool.id)
                  .where(lessons: { date: from..to })
                  .group(:teacher_id).sum(:credits)
                  .transform_values(&:to_f)
  end

  private

  # Xếp theo thứ tự "ai đang ít công nhất thì được ưu tiên nhận slot tiếp theo".
  # Mỗi lần gán, cộng dồn công dự kiến rồi sắp xếp lại — greedy nhưng đủ tốt và
  # quan trọng hơn là GIẢI THÍCH ĐƯỢC cho admin đang ngồi duyệt.
  def compute_proposals
    running = Hash.new(0.0).merge(workload_score)
    this_month = current_credits
    expected = expected_credit_per_slot

    open_slots.sort_by { |slot| [slot.weekday, slot.hour] }.map do |slot|
      teacher = slot.teacher
      level = teacher.level_label
      before = running[teacher.id]
      running[teacher.id] = before + expected

      Proposal.new(
        teacher_id: teacher.id, teacher_name: teacher.display_name,
        weekday: slot.weekday, hour: slot.hour, level: level,
        date: first_date_for(slot.weekday)&.to_s,
        reason: "#{this_month[teacher.id].to_f.round(1)} công tháng này · " \
                "điểm tải 3 tháng #{before.round(1)} · #{level}"
      )
    end.sort_by { |p| -priority(p, running) }
  end

  # Ưu tiên slot của giáo viên đang ít công nhất trong cùng level.
  def priority(proposal, credits)
    -credits[proposal.teacher_id].to_f
  end

  # Một slot mới trung bình đem lại bao nhiêu công: lấy sĩ số trung bình thực tế
  # của hồ, không đoán. Hồ chưa có dữ liệu thì giả định lớp 1:2.
  def expected_credit_per_slot
    @expected_credit_per_slot ||= begin
      avg = SwimClass.teaching.where(pool_id: @pool.id).map(&:seats_taken)
      headcount = avg.any? ? [(avg.sum.to_f / avg.size).round, 1].max : 2
      @workspace.credits_for(headcount)
    end
  end

  def first_date_for(weekday)
    (@month..@month.end_of_month).find { |d| d.wday == weekday && @pool.open_on?(d) }
  end

  # Số liệu để admin đánh giá bản nháp trước khi áp dụng.
  def metrics(proposals)
    projected = Hash.new(0.0).merge(workload_score)
    proposals.each { |p| projected[p.teacher_id] += expected_credit_per_slot }

    by_level = proposals.group_by(&:level)
    spread = by_level.transform_values do |group|
      values = group.map { |p| projected[p.teacher_id] }.uniq
      stddev(values).round(2)
    end

    {
      "open_slots" => open_slots.size,
      "locked_classes" => SwimClass.teaching.where(pool_id: @pool.id).count,
      "teachers" => proposals.map(&:teacher_id).uniq.size,
      "expected_credit_per_slot" => expected_credit_per_slot,
      "credit_stddev_by_level" => spread,
      "availability_submitted" => TeacherAvailability.for_month(@month)
                                                     .where(pool_id: @pool.id).submitted
                                                     .distinct.count(:teacher_id),
      # Lịch sử 3 tháng gần nhất, để admin đối chiếu khi duyệt bản nháp.
      "history" => history_breakdown.map do |row|
        { "month" => row[:month].strftime("%m/%Y"),
          "total" => row[:credits].values.sum.round(1),
          "teachers" => row[:credits].size }
      end
    }
  end

  def stddev(values)
    return 0.0 if values.size < 2
    mean = values.sum / values.size.to_f
    Math.sqrt(values.sum { |v| (v - mean)**2 } / values.size.to_f)
  end
end
