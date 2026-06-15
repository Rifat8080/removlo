module Admin
  class UsersController < BaseController
    before_action :require_admin!
    before_action :set_user, only: %i[show edit update destroy]

    def index
      authorize! :read, User
      @users = User.order(created_at: :desc)
      @role_counts = User.group(:role).count
    end

    def show
      authorize! :read, @user
    end

    def new
      @user = User.new(role: :customer)
      authorize! :create, @user
    end

    def edit
      authorize! :update, @user
    end

    def create
      @user = User.new(create_user_params)
      authorize! :create, @user

      if @user.save
        notify_user(@user, "Account created", "Your Removlo account was created by #{current_user.email}.")
        redirect_to admin_user_path(@user), notice: "User was created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      authorize! :update, @user

      attrs = update_user_params
      attrs.delete(:password) if attrs[:password].blank?
      attrs.delete(:password_confirmation) if attrs[:password_confirmation].blank?
      attrs.delete(:role) if @user == current_user

      if @user.update(attrs)
        notify_user(@user, "Account updated", "Your Removlo account details were updated.")
        redirect_to admin_user_path(@user), notice: "User was updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize! :destroy, @user

      if @user == current_user
        redirect_to admin_users_path, alert: "You cannot delete your own account."
        return
      end

      if @user.destroy
        redirect_to admin_users_path, notice: "User was deleted successfully."
      else
        redirect_to admin_user_path(@user), alert: @user.errors.full_messages.to_sentence
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def create_user_params
      attrs = params.require(:user).permit(:email, :password, :password_confirmation)
      attrs[:role] = safe_role_param if safe_role_param.present?
      attrs
    end

    def update_user_params
      attrs = params.require(:user).permit(:email, :password, :password_confirmation)
      attrs[:role] = safe_role_param if safe_role_param.present?
      attrs
    end

    def safe_role_param
      role = params.dig(:user, :role).to_s
      return if role.blank?
      return role if User.roles.key?(role)

      nil
    end

    def require_admin!
      authorize! :manage, :all
    rescue CanCan::AccessDenied
      redirect_to dashboard_path, alert: "You are not authorized to manage users."
    end

    def notify_user(user, title, body)
      ::ActivityNotifier.call(
        recipients: user,
        event_type: "user.account",
        title: title,
        body: body,
        url: dashboard_path,
        actor: current_user,
        notifiable: user
      )
    end
  end
end
