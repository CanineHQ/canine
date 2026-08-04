class ApplicationMailer < ActionMailer::Base
  default from: "no-reply@canine.sh"
  layout "mailer"
end
