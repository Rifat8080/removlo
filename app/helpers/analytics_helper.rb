module AnalyticsHelper
  def google_analytics_id
    ENV["GOOGLE_ANALYTICS_MEASUREMENT_ID"].presence
  end

  def google_analytics_enabled?
    google_analytics_id.present? && !Rails.env.test?
  end
end
