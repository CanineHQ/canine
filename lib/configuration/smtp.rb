module Configuration
  class SMTP
    def configured?
      address.present?
    end

    def address
      ENV["SMTP_ADDRESS"]
    end

    def port
      ENV.fetch("SMTP_PORT", 587).to_i
    end

    def username
      ENV["SMTP_USERNAME"]
    end

    def password
      ENV["SMTP_PASSWORD"]
    end

    def authentication
      ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym
    end

    def enable_starttls_auto?
      ENV.fetch("SMTP_ENABLE_STARTTLS", "true") == "true"
    end

    def domain
      ENV["SMTP_DOMAIN"]
    end

    def settings
      {
        address: address,
        port: port,
        user_name: username,
        password: password,
        authentication: authentication,
        enable_starttls_auto: enable_starttls_auto?,
        domain: domain
      }
    end
  end
end
