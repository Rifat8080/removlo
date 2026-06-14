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

  # Compress responses.
  config.middleware.insert_before ActionDispatch::Static, Rack::Deflater

  # Store uploaded files locally.
  config.active_storage.service = :local

  # IMPORTANT:
  # You do not have SSL/domain yet, so keep these false for IP access.
  config.force_ssl = false
  config.assume_ssl = false

  # Logging.
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging logs.
  config.silence_healthcheck_path = "/up"

  # Do not log deprecations.
  config.active_support.report_deprecations = false

  # Mailer host.
  # For now this uses your VM IP. Later replace APP_HOST with your real domain.
  app_host = ENV.fetch("APP_HOST", "34.45.166.78")
  app_protocol = ENV.fetch("APP_PROTOCOL", "http")

  config.action_mailer.default_url_options = {
    host: app_host,
    protocol: app_protocol
  }

  smtp_starttls = ENV.fetch("SMTP_ENABLE_STARTTLS_AUTO", "true").to_s.downcase.in?(["true", "1", "yes"])

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ADDRESS", "smtp-relay.brevo.com"),
    port: ENV.fetch("SMTP_PORT", 587).to_i,
    domain: ENV.fetch("SMTP_DOMAIN", app_host),
    user_name: ENV.fetch("SMTP_USERNAME", "aea73c001@smtp-brevo.com"),
    password: ENV["SMTP_PASSWORD"],
    authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
    enable_starttls_auto: smtp_starttls
  }.compact

  # Locale fallbacks.
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]

  # Host authorization.
  # This fixes your current 403 Blocked hosts issue.
  #
  # You can control it from /etc/removlo.env:
  # APP_HOSTS=34.45.166.78,127.0.0.1,localhost
  config.hosts = ENV.fetch(
    "APP_HOSTS",
    "34.45.166.78,127.0.0.1,localhost"
  ).split(",").map(&:strip)

  # Keep /up accessible for health checks.
  config.host_authorization = {
    exclude: ->(request) { request.path == "/up" }
  }
end