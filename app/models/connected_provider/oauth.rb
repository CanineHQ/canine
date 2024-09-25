module ConnectedProvider::Oauth
  extend ActiveSupport::Concern

  included do
    serialize :auth, coder: JSON

    encrypts :access_token
    encrypts :access_token_secret

    # Scopes for each provider
    Devise.omniauth_configs.each do |provider, _|
      scope provider, -> { where(provider: provider) }
    end
  end

  class_methods do
    def for_auth(auth)
      where(provider: auth.provider, uid: auth.uid).first
    end
  end

  def provider_name
    provider.humanize
  end

  def name
    auth&.dig("info", "name")
  end

  def email
    auth&.dig("info", "email")
  end

  def image_url
    auth&.dig("info", "image") || GravatarHelper.gravatar_url_for(email)
  end
end
