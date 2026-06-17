if ENV["SMTP_ADDRESS"].present?
  smtp_settings = {
    address: ENV["SMTP_ADDRESS"],
    port: ENV.fetch("SMTP_PORT", 587).to_i,
    domain: ENV["SMTP_DOMAIN"],
    user_name: ENV["SMTP_USERNAME"],
    password: ENV["SMTP_PASSWORD"],
    authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
    enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS_AUTO", "true") == "true",
    openssl_verify_mode: ENV.fetch("SMTP_OPENSSL_VERIFY_MODE", "peer")
  }.compact

  Rails.application.config.smtp_settings = smtp_settings
end
