# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  csp_report_only = ActiveModel::Type::Boolean.new.cast(ENV.fetch("CSP_REPORT_ONLY", "true"))

  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob, "https://www.google-analytics.com", "https://www.googletagmanager.com"
    policy.object_src  :none
    policy.script_src  :self, :https, :unsafe_inline, "https://js.stripe.com", "https://maps.googleapis.com", "https://maps.gstatic.com", "https://www.googletagmanager.com"
    policy.style_src   :self, :https, :unsafe_inline, "https://fonts.googleapis.com"
    policy.connect_src :self, :https, "wss:", "https://api.stripe.com", "https://maps.googleapis.com", "https://www.google-analytics.com", "https://www.googletagmanager.com", "https://region1.google-analytics.com"
    policy.frame_src   :self, "https://js.stripe.com", "https://hooks.stripe.com"
    policy.form_action :self, "https://checkout.stripe.com"
    policy.frame_ancestors :none
    policy.base_uri    :self
    policy.upgrade_insecure_requests if Rails.env.production? && !csp_report_only
  end

  # Keep CSP report-only until inline scripts/styles and third-party integrations are fully tuned.
  config.content_security_policy_report_only = csp_report_only

  config.permissions_policy do |policy|
    policy.camera      :none
    policy.microphone  :none
    policy.payment     :self, "https://checkout.stripe.com"
    policy.usb         :none
    policy.fullscreen  :self
  end
end
