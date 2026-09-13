module SmtpUtilities
  extend self

  def smtp_configured?
    ENV["SMTP_ADDRESS"].present?
  end

  def smtp_settings
    {
      address: ENV["SMTP_ADDRESS"],
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
      enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS", "true") == "true",
      domain: ENV["SMTP_DOMAIN"]
    }
  end

  def smtp_domain
    ENV["SMTP_DOMAIN"]
  end
end
