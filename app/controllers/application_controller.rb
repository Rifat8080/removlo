class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  layout :resolve_layout

  private

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
