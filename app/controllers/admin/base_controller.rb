module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_operator!

    layout "dashboard"

    private

    def require_operator!
      authorize! :access, :operations
    rescue CanCan::AccessDenied

      redirect_to dashboard_path, alert: "You are not authorized to access operations."
    end

    def require_admin!
      authorize! :manage, :all
    rescue CanCan::AccessDenied

      redirect_to admin_root_path, alert: "Only admins can perform this action."
    end
  end
end
