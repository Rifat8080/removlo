module Users
  class RegistrationsController < Devise::RegistrationsController
    SELF_SERVICE_ROLES = %w[customer driver].freeze

    before_action :set_signup_role, only: %i[new create]

    def new
      super do |resource|
        resource.role = @signup_role
      end
    end

    protected

    def build_resource(hash = {})
      super(hash.merge(role: @signup_role))
    end

    private

    def set_signup_role
      requested_role = params.dig(resource_name, :role).presence || params[:role].presence
      @signup_role = SELF_SERVICE_ROLES.include?(requested_role) ? requested_role : "customer"
    end
  end
end
module Users
  class RegistrationsController < Devise::RegistrationsController
    PUBLIC_ROLES = %w[customer driver].freeze

    before_action :configure_sign_up_params, only: :create

    def new
      super do |resource|
        resource.role = public_role_for(params[:role]) if params[:role].present?
      end
    end

    protected

    def build_resource(hash = {})
      super
      self.resource.role = public_role_for(resource.role)
    end

    def after_sign_up_path_for(_resource)
      dashboard_path
    end

    def configure_sign_up_params
      devise_parameter_sanitizer.permit(:sign_up, keys: [:role])
    end

    private

    def public_role_for(role)
      role = role.to_s
      PUBLIC_ROLES.include?(role) ? role : "customer"
    end
  end
end
