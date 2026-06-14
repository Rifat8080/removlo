class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAILER_FROM", "Removlo <info.removlo@gmail.com>") }
  layout "mailer"
end
