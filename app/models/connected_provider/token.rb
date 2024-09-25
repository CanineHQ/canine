module ConnectedProvider::Token
  extend ActiveSupport::Concern

  def token
    renew_token! if expired?
    access_token
  end

  def expired?
    expires_at? && expires_at <= 30.minutes.from_now
  end

  def renew_token!
    new_token = current_token.refresh!
    update(
      access_token: new_token.token,
      refresh_token: new_token.refresh_token,
      expires_at: Time.at(new_token.expires_at)
    )
  end

  private

  def current_token
    OAuth2::AccessToken.new(
      strategy.client,
      access_token,
      refresh_token:
    )
  end

  def credentials_for(provider)
    {
      private_key: ENV["OMNIAUTH_#{provider.to_s.upcase}_PRIVATE_KEY"],
      public_key: ENV["OMNIAUTH_#{provider.to_s.upcase}_PUBLIC_KEY"]
    }.compact
  end

  def strategy
    provider_config = credentials_for(provider)
    OmniAuth::Strategies.const_get(OmniAuth::Utils.camelize(provider).to_s).new(
      nil,
      provider_config[:public_key], # client id
      provider_config[:private_key] # client secret
    )
  end
end
