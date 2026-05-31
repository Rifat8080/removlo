module Driver
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_driver!

    layout "dashboard"

    private

    def require_driver!
      return if current_user&.driver?

      redirect_to dashboard_path, alert: "You are not authorized to access driver jobs."
    end
  end
end
