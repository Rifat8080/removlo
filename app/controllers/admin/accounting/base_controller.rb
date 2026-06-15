# frozen_string_literal: true

module Admin
  module Accounting
    class BaseController < Admin::BaseController
      before_action :require_admin!

      private

      def require_admin!
        authorize! :manage, :all
      rescue CanCan::AccessDenied
        redirect_to dashboard_path, alert: "You are not authorized to access accounting."
      end

      def parse_money_param(attrs, field)
        value = attrs.delete(field)
        attrs[:"#{field}_cents"] = (BigDecimal(value.presence || "0") * 100).to_i if value
        attrs
      end

      def parse_amount_param(attrs)
        value = attrs.delete(:amount)
        attrs[:amount_cents] = (BigDecimal(value.presence || "0") * 100).to_i
        attrs
      end
    end
  end
end
