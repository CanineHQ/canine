class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_SENDER", "no-reply@canine.local")
  layout "mailer"
end
