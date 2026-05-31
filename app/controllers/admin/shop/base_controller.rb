module Admin
  module Shop
    class BaseController < Admin::BaseController
      before_action :require_admin!

      private

      def require_admin!
        return if current_user&.admin?

        redirect_to dashboard_path, alert: "You are not authorized to manage the shop."
      end

      def parse_price_param(attrs)
        value = attrs.delete(:price)
        attrs[:price_cents] = (BigDecimal(value.presence || "0") * 100).to_i
        attrs
      end
    end
  end
end
