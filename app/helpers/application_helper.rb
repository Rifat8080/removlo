module ApplicationHelper
  def safe_external_url(url, allowed_hosts: nil)
    parsed_url = URI.parse(url.to_s)
    return unless parsed_url.is_a?(URI::HTTP) && parsed_url.host.present?

    if allowed_hosts.present?
      host = parsed_url.host.downcase
      allowed = Array(allowed_hosts).any? { |allowed_host| host == allowed_host || host.end_with?(".#{allowed_host}") }
      return unless allowed
    end

    parsed_url.to_s
  rescue URI::InvalidURIError
    nil
  end

  def safe_google_url(url)
    safe_external_url(url, allowed_hosts: %w[google.com google.co.uk])
  end
end
