module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!
    before_action :set_user, only: %i[show edit update destroy]

    layout "dashboard"

    def index
      @users = User.order(created_at: :desc)
      @role_counts = User.group(:role).count
    end

    def show
    end

    def new
      @user = User.new(role: :customer)
    end

    def edit
    end

    def create
      @user = User.new(create_user_params)

      if @user.save
        redirect_to admin_user_path(@user), notice: "User was created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      attrs = update_user_params
      attrs.delete(:password) if attrs[:password].blank?
      attrs.delete(:password_confirmation) if attrs[:password_confirmation].blank?

      if @user.update(attrs)
        redirect_to admin_user_path(@user), notice: "User was updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: "You cannot delete your own account."
        return
      end

      @user.destroy
      redirect_to admin_users_path, notice: "User was deleted successfully."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def create_user_params
      params.require(:user).permit(:email, :role, :password, :password_confirmation)
    end

    def update_user_params
      params.require(:user).permit(:email, :role, :password, :password_confirmation)
    end

    def require_admin!
      return if current_user&.admin?

      redirect_to dashboard_path, alert: "You are not authorized to manage users."
    end
  end
end
