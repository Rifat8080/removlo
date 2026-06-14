class ApplicationController < ActionController::Base
  rescue_from CanCan::AccessDenied, with: :deny_access

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include CartManagement

  layout :resolve_layout

  private

  def deny_access(exception)
    respond_to do |format|
      format.html { redirect_to after_access_denied_path, alert: exception.message.presence || "You are not authorized to access that page." }
      format.json { render json: { error: "forbidden" }, status: :forbidden }
      format.turbo_stream { redirect_to after_access_denied_path, alert: exception.message.presence || "You are not authorized to access that page." }
      format.any { head :forbidden }
    end
  end

  def after_access_denied_path
    user_signed_in? ? dashboard_path : new_user_session_path
  end

  def current_ability
    @current_ability ||= Ability.new(current_user, cart_session_token: session[:cart_token])
  end

  def resolve_layout
    return "application" unless devise_controller?

    # Keep "edit profile" inside the signed-in dashboard shell; use the
    # focused auth layout for sign in / sign up / password flows.
    if controller_name == "registrations" && action_name == "edit"
      "dashboard"
    else
      "auth"
    end
  end
end
