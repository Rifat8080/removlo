class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAILER_FROM", "Removlo <hello@removlo.com>") }
  layout "mailer"
end
