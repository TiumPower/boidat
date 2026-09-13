module Coach
  # Lịch dạy của tôi (FR-302). Mỗi slot có trạng thái "đã có lớp" hoặc "trống"
  # — slot trống là khung giáo viên đã đăng ký dạy mà sale chưa xếp học viên.
  class ScheduleController < BaseController
    def index
      @date = parse_date(params[:date]) || Date.current
      @teacher = current_teacher
      @lessons = Lesson.where(teacher_id: @teacher.id, date: @date)
                       .where.not(status: "cancelled")
                       .includes(swim_class: [:course, enrollments: :student], attendances: :student)
                       .order(:start_hour).to_a
      @free_slots = free_slots_for(@date)
      @summary = day_summary
      @rental_blocks = @teacher.renter? ? rental_blocks : []
    end

    private

    def nav_key = :schedule

    # Khung đã đăng ký dạy nhưng chưa có lớp nào rơi vào — hiện để giáo viên biết
    # sale còn chỗ trống của mình mà chốt khách.
    def free_slots_for(date)
      taken = @lessons.map(&:start_hour)
      TeacherAvailability.for_month(date).where(teacher: @teacher, weekday: date.wday)
                         .where.not(hour: taken).order(:hour).includes(:pool).to_a
    end

    def day_summary
      credits = TimesheetEntry.where(teacher_id: @teacher.id)
                              .joins(:lesson).where(lessons: { date: @date }).sum(:credits)
      pending = @lessons.count do |l|
        l.status == "done" &&
          l.swim_class.active_enrollments.map(&:student_id).any? { |sid| l.session_feedbacks.none? { |f| f.student_id == sid } }
      end
      { lessons: @lessons.size, credits: credits, pending_feedback: pending }
    end

    # Giáo viên thuê hồ chỉ thấy khung giờ đã thuê (FR-225).
    def rental_blocks
      SwimClass.rentals.where(teacher_id: @teacher.id, status: "running").includes(:pool).to_a
    end

    def parse_date(value)
      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
