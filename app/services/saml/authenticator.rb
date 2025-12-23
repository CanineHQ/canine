# app/services/saml/authenticator.rb
module SAML
  class Authenticator
    Result = Struct.new(
      :success?,
      :email,
      :name,
      :uid,
      :groups,
      :error_message,
      keyword_init: true
    )

    def initialize(saml_configuration, account:, logger: Rails.logger)
      @config = saml_configuration
      @account = account
      @logger = logger
    end

    def authenticate(saml_response:)
      response = OneLogin::RubySaml::Response.new(
        saml_response,
        settings: settings,
        allowed_clock_drift: 30.seconds
      )

      unless response.is_valid?
        @logger.error "SAML auth: invalid response - #{response.errors.join(', ')}"
        return Result.new(success?: false, error_message: response.errors.first || "Invalid SAML response")
      end

      attributes = response.attributes

      email = extract_attribute(attributes, config.email_attribute) || response.nameid
      name = extract_attribute(attributes, config.name_attribute)
      uid = extract_attribute(attributes, config.uid_attribute) || response.nameid

      if email.blank?
        return Result.new(success?: false, error_message: "Email not found in SAML response")
      end

      Result.new(
        success?: true,
        email: email,
        name: name,
        uid: uid,
        groups: extract_groups(attributes),
        error_message: nil
      )
    rescue => e
      @logger.error "SAML auth: unexpected error - #{e.class}: #{e.message}"
      Result.new(success?: false, error_message: e.message)
    end

    def authorization_url(relay_state: nil)
      request = OneLogin::RubySaml::Authrequest.new
      request.create(settings, RelayState: relay_state)
    end

    def settings
      @settings ||= config.settings_for(@account)
    end

    def metadata
      meta = OneLogin::RubySaml::Metadata.new
      meta.generate(settings, true)
    end

    private

    attr_reader :config, :logger

    def extract_attribute(attributes, attr_name)
      return nil if attr_name.blank?

      value = attributes[attr_name]
      value = value.first if value.is_a?(Array)
      value
    end

    def extract_groups(attributes)
      return [] if config.groups_attribute.blank?

      groups = attributes[config.groups_attribute]
      return [] if groups.blank?

      groups = [ groups ] unless groups.is_a?(Array)
      groups.map { |g| { name: g.to_s } }
    end
  end
end
