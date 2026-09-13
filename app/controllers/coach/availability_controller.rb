module Coach
  # Giáo viên đăng ký khung giờ sẵn sàng dạy trong tháng tới (FR-304).
  # Đây là đầu vào bắt buộc của bộ xếp lịch tự động và là nguồn của "slot trống"
  # trên bảng master data — chưa ai gửi lịch thì sale không có gì để chốt.
  class AvailabilityController < BaseController
    def edit
      @month = target_month
      @pools = current_teacher.pools.to_a
      @hours = hours_for(@pools)
      @selected = selected_slots(@month)
      @deadline = deadline_for(@month)
      @conflicts = TeacherAvailability.conflicts_for(current_teacher, @month)
      @submitted = TeacherAvailability.for_month(@month).where(teacher: current_teacher)
                                      .where.not(submitted_at: nil).exists?
    end

    def update
      month = target_month
      count = TeacherAvailability.replace_month!(teacher: current_teacher, month: month,
                                                 slots: params[:slots], submitted: true)
      redirect_to teacher_availability_path(month: month.strftime("%Y-%m")),
                  notice: "Đã gửi #{count} ca cho tháng #{month.strftime('%m/%Y')}."
    end

    private

    def nav_key = :availability

    # Mặc định là tháng sau — đăng ký lịch luôn cho kỳ tới, không phải kỳ đang chạy.
    def target_month
      raw = params[:month].presence
      raw ? Date.strptime(raw, "%Y-%m") : Date.current.next_month.beginning_of_month
    rescue ArgumentError
      Date.current.next_month.beginning_of_month
    end

    def selected_slots(month)
      TeacherAvailability.for_month(month).where(teacher: current_teacher)
                         .pluck(:pool_id, :weekday, :hour)
                         .map { |pid, wd, h| "#{pid}:#{wd}:#{h}" }.to_set
    end

    # Chỉ hiện các giờ hồ thực sự mở cửa, đỡ phải cuộn qua hàng chục dòng trống.
    def hours_for(pools)
      pools.flat_map { |p| (0..6).flat_map { |wd| p.operating_hours.find_by(weekday: wd)&.then { |h| h.closed? ? [] : (h.opens_at.hour...h.closes_at.hour).to_a } || [] } }
           .uniq.sort
    end

    def deadline_for(month)
      day = current_workspace.availability_deadline_day
      (month - 1.month).change(day: [day, (month - 1.month).end_of_month.day].min)
    end
  end
end
