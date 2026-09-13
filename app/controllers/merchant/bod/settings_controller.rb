module Merchant
  module Bod
    # Màn hình chốt các quy tắc nghiệp vụ (§4 kế hoạch). Đây là nơi khách đổi ý
    # về 11/12 buổi, công lớp 1:4, cách tính công khi học viên vắng… mà không
    # cần đội dev deploy lại.
    class SettingsController < BaseController
      def edit
        @settings = current_workspace.business_settings
      end

      def update
        before = current_workspace.business_settings
        current_workspace.update_business_settings!(normalized_params)
        audit!("update", current_workspace, summary: "Sửa cấu hình nghiệp vụ",
               before: before, after: current_workspace.business_settings)
        redirect_to merchant_bod_settings_path, notice: "Đã lưu cấu hình."
      end

      private

      def nav_key = :settings

      BOOLEANS = %w[feedback_blocks_payroll exam_deducts_session exam_pays_credit
                    exam_eligible_sticky no_show_deducts day_pass_uses_face
                    rental_revenue_separate].freeze
      INTEGERS = %w[course_sessions graduation_at_session
                    package_validity_days expiry_warning_days feedback_deadline_hours
                    availability_deadline_day lesson_minutes low_sessions_threshold
                    face_recent_window].freeze
      # Để trống nghĩa là "kỳ thi xếp riêng, không buổi nào trong khoá là buổi
      # thi" — khác hẳn với 0, nên phải giữ được giá trị nil (OQ-25).
      NULLABLE_INTEGERS = %w[exam_session_index].freeze
      FLOATS   = %w[face_match_threshold face_review_threshold face_recapture_fail_ratio].freeze
      STRINGS  = %w[credit_basis household_scope_payments].freeze

      def normalized_params
        raw = params.require(:settings)
        out = {}
        BOOLEANS.each { |k| out[k] = raw[k] == "1" }
        INTEGERS.each { |k| out[k] = raw[k].to_i if raw[k].present? }
        NULLABLE_INTEGERS.each { |k| out[k] = raw[k].presence&.to_i if raw.key?(k) }
        FLOATS.each   { |k| out[k] = raw[k].to_f if raw[k].present? }
        STRINGS.each  { |k| out[k] = raw[k] if raw[k].present? }
        if raw[:credit_table].present?
          out["credit_table"] = raw[:credit_table].to_unsafe_h
                                   .transform_values(&:to_f).select { |_, v| v.positive? }
        end
        out
      end
    end
  end
end
