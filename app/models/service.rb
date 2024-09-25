class Service < ApplicationRecord
  belongs_to :user

  Devise.omniauth_configs.keys.each do |provider|
    scope provider, ->{ where(provider: provider) }
  end

  def client
    send("#{provider}_client")
  end

  def expired?
    expires_at? && expires_at <= Time.zone.now
  end

  def access_token
    send("#{provider}_refresh_token!", super) if expired?
    super
  end


  def twitter_client
    Twitter::REST::Client.new do |config|
      config.consumer_key        = Rails.application.secrets.twitter_app_id
      config.consumer_secret     = Rails.application.secrets.twitter_app_secret
      config.access_token        = access_token
      config.access_token_secret = access_token_secret
    end
  end

  def twitter_refresh_token!(token); end
end
