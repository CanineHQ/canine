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
#  registry_url        :string
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
  attr_accessor :username_param
  GITHUB_PROVIDER = "github"
  CUSTOM_REGISTRY_PROVIDER = "container_registry"
  GITLAB_PROVIDER = "gitlab"
  PORTAINER_PROVIDER = "portainer"
  GIT_TYPE = "git"
  REGISTRY_TYPE = "registry"
  PROVIDER_TYPES = {
    GIT_TYPE => [ GITHUB_PROVIDER, GITLAB_PROVIDER ],
    REGISTRY_TYPE => [ CUSTOM_REGISTRY_PROVIDER ]
  }

  AVAILABLE_PROVIDERS = [ GITHUB_PROVIDER, GITLAB_PROVIDER, CUSTOM_REGISTRY_PROVIDER ].freeze
  validates :registry_url, presence: true, if: :container_registry?
  scope :has_container_registry, -> { where(provider: [ GITHUB_PROVIDER, GITLAB_PROVIDER, CUSTOM_REGISTRY_PROVIDER ]) }

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

  def git?
    github? || gitlab?
  end

  def expired?
    expires_at? && expires_at <= Time.zone.now
  end

  def access_token
    send("#{provider}_refresh_token!", super) if expired?
    super
  end

  def container_registry?
    provider == CUSTOM_REGISTRY_PROVIDER
  end

  def github?
    provider == GITHUB_PROVIDER
  end

  def gitlab?
    provider == GITLAB_PROVIDER
  end

  def twitter_refresh_token!(token); end

  def used!
    update!(last_used_at: Time.current)
  end

  def friendly_name
    if container_registry?
      "#{registry_url} (#{username})"
    else
      "#{provider.titleize} (#{username})"
    end
  end

  def registry_base_url
    if github?
      "ghcr.io"
    elsif gitlab?
      "registry.gitlab.com"
    elsif container_registry?
      registry_url
    else
      raise "Unknown registry url"
    end
  end
end
