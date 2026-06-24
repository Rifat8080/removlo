module AnalyticsHelper
  # Public GA4 property ID (visible in page source). Override via ENV when needed.
  DEFAULT_MEASUREMENT_ID = "G-22XJ24NK9F"

  def google_analytics_id
    ENV["GOOGLE_ANALYTICS_MEASUREMENT_ID"].presence ||
      (Rails.env.production? ? DEFAULT_MEASUREMENT_ID : nil)
  end

  def google_analytics_enabled?
    google_analytics_id.present? && !Rails.env.test?
  end
end
