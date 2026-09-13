module Merchant
  module Ops
    # Theo dõi học bù ở phía trung tâm: ai chưa chọn phương án, ai đã đặt buổi nào.
    class MakeupsController < BaseController
      def index
        scope = MakeupRequest.where(pool_id: current_pool.id)
                             .includes(:student, from_lesson: :teacher, to_lesson: :teacher)
        @pending = scope.pending.recent.to_a
        @booked = scope.where(status: "booked").recent.limit(40).to_a
      end
    end
  end
end
