class ApplicationMailer < ActionMailer::Base
  default from: "no-reply@canine.sh"
  layout "mailer"

  def self.manageable
    before_action { @manageable = true }
  end
end
