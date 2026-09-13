module Merchant
  module Bod
    # Gói sản phẩm & bảng giá (FR-213, FR-214). Quyền sửa giá cố tình giữ ở cấp
    # BOD (OQ-20): cùng một người vừa tạo học viên vừa đặt giá vừa tạo đơn thì
    # không còn chốt chặn nào chống gian lận.
    class PackagesController < BaseController
      before_action :set_package, only: [:show, :edit, :update, :destroy]

      def index
        @kind = Package::KINDS.include?(params[:kind]) ? params[:kind] : nil
        scope = Package.ordered.includes(:course, price_list_items: :pool)
        scope = scope.where(kind: @kind) if @kind
        @packages = scope.to_a
        @counts = Package.group(:kind).count
        @pools = accessible_pools
      end

      def show
        @prices = @package.price_list_items.includes(:pool).order(:pool_id, effective_from: :desc).to_a
        @pools = accessible_pools
      end

      def new
        @package = Package.new(workspace: current_workspace, kind: params[:kind].presence || "full_course",
                               status: "active", class_type: 2)
      end

      def create
        @package = Package.new(package_params.merge(workspace: current_workspace))
        if @package.save
          audit!("create", @package, summary: "Tạo gói #{@package.name}")
          redirect_to merchant_bod_package_path(@package), notice: "Đã tạo gói. Thêm giá cho từng hồ ở bên dưới."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        before = @package.attributes.dup
        if @package.update(package_params)
          audit!("update", @package, summary: "Sửa gói #{@package.name}", before: before, after: @package.attributes)
          redirect_to merchant_bod_package_path(@package), notice: "Đã lưu."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        audit!("destroy", @package, summary: "Xoá gói #{@package.name}")
        @package.destroy
        redirect_to merchant_bod_packages_path, notice: "Đã xoá gói."
      end

      private

      def nav_key = :packages
      def set_package = @package = Package.find(params[:id])

      def package_params
        params.require(:package).permit(:name, :kind, :course_id, :class_type, :sessions,
                                        :validity_days, :status, :description, :position)
      end
    end
  end
end
