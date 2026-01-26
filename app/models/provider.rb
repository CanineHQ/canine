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
#  external_id         :string
#  sso_provider_id     :bigint
#  user_id             :bigint           not null
#
# Indexes
#
#  index_providers_on_sso_provider_id          (sso_provider_id)
#  index_providers_on_sso_provider_id_and_uid  (sso_provider_id,uid) UNIQUE WHERE (sso_provider_id IS NOT NULL)
#  index_providers_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (sso_provider_id => sso_providers.id)
#  fk_rails_...  (user_id => users.id)
#
class Provider < ApplicationRecord
  attr_accessor :username_param
  GITHUB_PROVIDER = "github"
  GITHUB_API_BASE = "https://api.github.com"
  CUSTOM_REGISTRY_PROVIDER = "container_registry"
  GITLAB_PROVIDER = "gitlab"
  GITLAB_API_BASE = "https://gitlab.com"
  BITBUCKET_PROVIDER = "bitbucket"
  BITBUCKET_API_BASE = "https://api.bitbucket.org"
  GIT_TYPE = "git"
  REGISTRY_TYPE = "registry"
  PROVIDER_TYPES = {
    GIT_TYPE => [ GITHUB_PROVIDER, GITLAB_PROVIDER, BITBUCKET_PROVIDER ],
    REGISTRY_TYPE => [ CUSTOM_REGISTRY_PROVIDER ]
  }

  PORTAINER_PROVIDER = "portainer"

  AVAILABLE_PROVIDERS = [ GITHUB_PROVIDER, GITLAB_PROVIDER, BITBUCKET_PROVIDER, CUSTOM_REGISTRY_PROVIDER ].freeze
  validates :registry_url, presence: true, if: :container_registry?
  scope :has_container_registry, -> { where(provider: [ GITHUB_PROVIDER, GITLAB_PROVIDER, CUSTOM_REGISTRY_PROVIDER ]) }
  scope :non_sso, -> { where(sso_provider_id: nil) }

  belongs_to :user
  belongs_to :sso_provider, class_name: "SSOProvider", optional: true

  Devise.omniauth_configs.keys.each do |provider|
    scope provider, -> { where(provider: provider) }
  end

  def client
    send("#{provider}_client")
  end

  def username
    return unless auth
    JSON.parse(auth).dig("info", "nickname") || JSON.parse(auth).dig("info", "username")
  end

  def git?
    github? || gitlab? || bitbucket?
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

  def bitbucket?
    provider == BITBUCKET_PROVIDER
  end

  def enterprise?
    (github? || gitlab? || bitbucket?) && registry_url.present?
  end

  def api_base_url
    if registry_url.present?
      registry_url.chomp("/")
    elsif github?
      GITHUB_API_BASE
    elsif gitlab?
      GITLAB_API_BASE
    elsif bitbucket?
      BITBUCKET_API_BASE
    end
  end

  def twitter_refresh_token!(token); end

  def used!
    update!(last_used_at: Time.current)
  end

  def abbreviated_access_token
    token = read_attribute(:access_token)
    return "" if token.blank?

    middle_stars = "*" * [ 0, [ 10, token.length - 6 ].min ].max
    "#{token.first(4)}#{middle_stars}#{token.last(2)}"
  end

  def friendly_name
    if container_registry?
      "#{registry_url} (#{username}) - #{abbreviated_access_token}"
    else
      "#{provider.titleize} (#{username}) - #{abbreviated_access_token}"
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
