require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings.
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Serve static files from /public, needed behind Nginx.
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
  config.public_file_server.headers = {
    "cache-control" => "public, max-age=#{1.year.to_i}"
  }

  # Compress responses when Rails serves static files (e.g. behind a reverse proxy without gzip).
  if ENV["RAILS_SERVE_STATIC_FILES"].present?
    config.middleware.insert_before ActionDispatch::Static, Rack::Deflater
  end

  # Store uploaded files locally.
  config.active_storage.service = :local

  # SSL.
  # Before Certbot succeeds, keep FORCE_SSL=false in /etc/removlo.env.
  # After SSL succeeds, remove that override or set FORCE_SSL=true.
  force_ssl = ENV.fetch("FORCE_SSL", "true").to_s.downcase.in?(["true", "1", "yes"])

  config.force_ssl = force_ssl
  config.assume_ssl = force_ssl

  config.action_dispatch.default_headers = {
    "X-Frame-Options" => "DENY",
    "X-Content-Type-Options" => "nosniff",
    "Referrer-Policy" => "strict-origin-when-cross-origin",
    "X-Permitted-Cross-Domain-Policies" => "none"
  }

  # Logging.
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging logs.
  config.silence_healthcheck_path = "/up"

  # Do not log deprecations.
  config.active_support.report_deprecations = false

  # Host authorization.
  # This fixes the 403 forbidden issue for removlo.co.uk.
  config.hosts = ENV.fetch(
    "APP_HOSTS",
    "removlo.co.uk,www.removlo.co.uk,34.45.166.78,127.0.0.1,localhost"
  ).split(",").map(&:strip)

  # Keep /up accessible for health checks.
  config.host_authorization = {
    exclude: ->(request) { request.path == "/up" }
  }

  # Mailer host.
  app_host = ENV.fetch("APP_HOST", "removlo.co.uk")
  app_protocol = ENV.fetch("APP_PROTOCOL", force_ssl ? "https" : "http")

  config.action_mailer.default_url_options = {
    host: app_host,
    protocol: app_protocol
  }

  config.action_mailer.default_options = {
    from: ENV.fetch("DEFAULT_FROM_EMAIL", "Removlo <support@removlo.co.uk>")
  }

  smtp_starttls = ENV.fetch("SMTP_ENABLE_STARTTLS_AUTO", "true").to_s.downcase.in?(["true", "1", "yes"])

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ADDRESS", "smtp-relay.brevo.com"),
    port: ENV.fetch("SMTP_PORT", 587).to_i,
    domain: ENV.fetch("SMTP_DOMAIN", app_host),
    user_name: ENV.fetch("SMTP_USERNAME"),
    password: ENV.fetch("SMTP_PASSWORD"),
    authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
    enable_starttls_auto: smtp_starttls
  }

  # Locale fallbacks.
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]
end