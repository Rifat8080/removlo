module AnalyticsHelper
  # Public GA4 property ID (visible in page source). Override via ENV when needed.
  DEFAULT_MEASUREMENT_ID = "G-22XJ24NK9F"
  CONSENT_STORAGE_KEY = "removlo:analytics-consent"

  # EEA member states plus the UK (UK GDPR alignment for removlo.co.uk).
  CONSENT_REGION_COUNTRY_CODES = %w[
    AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE
    IS LI NO GB
  ].freeze

  def google_analytics_id
    ENV["GOOGLE_ANALYTICS_MEASUREMENT_ID"].presence ||
      (Rails.env.production? ? DEFAULT_MEASUREMENT_ID : nil)
  end

  def google_analytics_enabled?
    google_analytics_id.present? && !Rails.env.test?
  end

  def cookie_consent_banner_required?
    google_analytics_enabled? && consent_region_user?
  end

  def consent_region_user?
    code = request_country_code
    return dev_consent_region_override? if code.blank? && !Rails.env.production?
    return consent_region_when_geo_unknown? if code.blank?

    CONSENT_REGION_COUNTRY_CODES.include?(code)
  end

  def request_country_code
    override = ENV["DEV_CONSENT_COUNTRY"].presence
    return override.upcase if override.present? && !Rails.env.production?

    country_from_headers&.upcase
  end

  private

  def dev_consent_region_override?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("CONSENT_REGION_OVERRIDE", "false"))
  end

  def consent_region_when_geo_unknown?
    Rails.env.production? && request.host.to_s.end_with?("removlo.co.uk")
  end

  def country_from_headers
    [
      request.headers["CF-IPCountry"],
      request.headers["X-Country-Code"],
      request.get_header("HTTP_CF_IPCOUNTRY"),
      request.get_header("HTTP_X_COUNTRY_CODE")
    ].find { |value| value.present? && value != "XX" }
  end
end
