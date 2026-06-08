class WebPushSubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_json_request!, only: %i[create destroy]
  protect_from_forgery except: %i[create destroy]

  def configuration
    response.set_header("Cache-Control", "no-store")
    render json: {
      public_key: ENV["VAPID_PUBLIC_KEY"],
      enabled: ENV["VAPID_PUBLIC_KEY"].present? && ENV["VAPID_PRIVATE_KEY"].present?
    }
  end

  def create
    return render json: { ok: false, error: "Web push is not configured." }, status: :service_unavailable unless web_push_configured?

    subscription = WebPushSubscription.find_or_initialize_by(endpoint: subscription_params[:endpoint].to_s.strip)
    subscription.update!(
      user: current_user,
      p256dh_key: subscription_params.dig(:keys, :p256dh),
      auth_key: subscription_params.dig(:keys, :auth),
      user_agent: request.user_agent,
      last_failure_at: nil,
      last_error: nil
    )

    render json: { ok: true, subscribed: true }
  rescue ActionController::ParameterMissing
    render json: { ok: false, error: "Subscription payload is missing." }, status: :bad_request
  rescue ActiveRecord::RecordInvalid => e
    render json: { ok: false, error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def destroy
    current_user.web_push_subscriptions.where(endpoint: params[:endpoint]).destroy_all if params[:endpoint].present?
    render json: { ok: true, subscribed: false }
  end

  private

  def subscription_params
    params.require(:subscription).permit(:endpoint, keys: %i[p256dh auth])
  end

  def require_json_request!
    return if request.format.json?

    render json: { ok: false, error: "JSON requests only." }, status: :not_acceptable
  end

  def web_push_configured?
    ENV["VAPID_PUBLIC_KEY"].present? && ENV["VAPID_PRIVATE_KEY"].present?
  end
end
