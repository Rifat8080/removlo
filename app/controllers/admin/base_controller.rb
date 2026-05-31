module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_operator!

    layout "dashboard"

    private

    def require_operator!
      return if current_user&.operator?

      redirect_to dashboard_path, alert: "You are not authorized to access operations."
    end
  end
end
