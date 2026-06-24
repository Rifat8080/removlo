class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAILER_FROM", "Removlo <support@removlo.co.uk>") }
  layout "mailer"
end
