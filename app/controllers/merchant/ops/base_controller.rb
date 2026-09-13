module Merchant
  module Ops
    class BaseController < Merchant::BaseController
      before_action :require_operations!
      before_action :require_pool!
    end
  end
end
