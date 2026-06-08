module Users
  class RegistrationsController < Devise::RegistrationsController
    SELF_SERVICE_ROLES = %w[customer driver].freeze

    before_action :set_signup_role, only: %i[new create]
    before_action :store_return_to, only: :new
    before_action :configure_sign_up_params, only: :create

    def new
      super do |resource|
        resource.role = @signup_role
      end
    end

    protected

    def build_resource(hash = {})
      super(hash.merge(role: @signup_role))
    end

    def after_sign_up_path_for(_resource)
      stored = session.delete(:return_to)
      return stored if stored.present? && safe_return_path?(stored)

      dashboard_path
    end

    def configure_sign_up_params
      devise_parameter_sanitizer.permit(:sign_up, keys: [:role])
    end

    private

    def set_signup_role
      requested_role = params.dig(resource_name, :role).presence || params[:role].presence
      @signup_role = SELF_SERVICE_ROLES.include?(requested_role) ? requested_role : "customer"
    end

    def store_return_to
      session[:return_to] = params[:return_to] if params[:return_to].present?
    end

    def safe_return_path?(path)
      path.start_with?("/") && !path.start_with?("//")
    end
  end
end
