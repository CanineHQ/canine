# == Schema Information
#
# Table name: providers
#
#  id                  :bigint           not null, primary key
#  access_token        :string
#  access_token_secret :string
#  auth                :text
#  expires_at          :datetime
#  last_used_at        :datetime
#  provider            :string
#  refresh_token       :string
#  uid                 :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  user_id             :bigint           not null
#
# Indexes
#
#  index_providers_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Provider < ApplicationRecord
  attr_accessor :username
  GITHUB_PROVIDER = "github"
  DOCKER_HUB_PROVIDER = "docker_hub"
  AVAILABLE_PROVIDERS = [ GITHUB_PROVIDER, DOCKER_HUB_PROVIDER ].freeze

  belongs_to :user

  Devise.omniauth_configs.keys.each do |provider|
    scope provider, -> { where(provider: provider) }
  end

  def client
    send("#{provider}_client")
  end

  def username
    JSON.parse(auth)["info"]["nickname"] || JSON.parse(auth)["info"]["username"]
  end

  def registry
    if github?
      "ghcr.io"
    else
      "https://index.docker.io/v1/"
    end
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

  def docker_hub?
    provider == DOCKER_HUB_PROVIDER
  end

  def github?
    provider == GITHUB_PROVIDER
  end

  def twitter_refresh_token!(token); end

  def used!
    update!(last_used_at: Time.current)
  end
end
