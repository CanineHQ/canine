  # Gem names are usually "google-oauth2"
  # Provider names are usually "google_oauth2" because symbols don't support hyphens

  module Omniauth
    autoload :Callbacks, "omniauth/callbacks"
    # Look up credentials for a provider (assumes an underscored name), ENV variables take precedence
    # omniauth:
    #   github:
    #     private_key: x
    #     public_key: y
    def self.credentials_for(provider)
      credentials = Rails.application.credentials.dig(Rails.env, provider) || {}
      credentials.merge({
        private_key: ENV["OMNIAUTH_#{provider.upcase}_PRIVATE_KEY"],
        public_key: ENV["OMNIAUTH_#{provider.upcase}_PUBLIC_KEY"]
      }.compact)
    end

    # Returns a hash of all the other keys and values in the omniauth hash for this provider
    def self.options_for(provider)
      credentials_for(provider).except(:public_key, :private_key)
    end
  end
