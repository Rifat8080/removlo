class WebPushSubscriptionsController < ApplicationController
  before_action :authenticate_user!
  protect_from_forgery except: :create

  def config
    render json: {
      public_key: ENV["VAPID_PUBLIC_KEY"],
      enabled: ENV["VAPID_PUBLIC_KEY"].present? && ENV["VAPID_PRIVATE_KEY"].present?
    }
  end

  def create
    subscription = current_user.web_push_subscriptions.find_or_initialize_by(endpoint: subscription_params[:endpoint])
    subscription.update!(
      p256dh_key: subscription_params.dig(:keys, :p256dh),
      auth_key: subscription_params.dig(:keys, :auth),
      user_agent: request.user_agent
    )

    render json: { ok: true }
  rescue ActiveRecord::RecordInvalid => e
    render json: { ok: false, error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def destroy
    current_user.web_push_subscriptions.where(endpoint: params[:endpoint]).destroy_all if params[:endpoint].present?
    render json: { ok: true }
  end

  private

  def subscription_params
    params.require(:subscription).permit(:endpoint, keys: %i[p256dh auth])
  end
end
