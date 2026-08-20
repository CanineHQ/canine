# == Schema Information
#
# Table name: accounts
#
#  id                     :bigint           not null, primary key
#  allow_mcp              :boolean          default(TRUE), not null
#  name                   :string           not null
#  plan                   :integer          default("free"), not null
#  slug                   :string           not null
#  subscription_status    :string
#  trial_ends_at          :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  owner_id               :bigint
#  stripe_customer_id     :string
#  stripe_subscription_id :string
#
# Indexes
#
#  index_accounts_on_owner_id                (owner_id)
#  index_accounts_on_slug                    (slug) UNIQUE
#  index_accounts_on_stripe_customer_id      (stripe_customer_id) UNIQUE
#  index_accounts_on_stripe_subscription_id  (stripe_subscription_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (owner_id => users.id)
#
class Account < ApplicationRecord
  include Billable

  extend FriendlyId
  friendly_id :name, use: :slugged

  def self.ransackable_attributes(auth_object = nil)
    %w[name slug]
  end

  belongs_to :owner, class_name: "User"
  has_many :account_users, dependent: :destroy
  has_many :users, through: :account_users
  has_one :stack_manager, dependent: :destroy
  has_one :sso_provider, dependent: :destroy
  has_many :teams, dependent: :destroy

  has_many :clusters, dependent: :destroy
  has_many :build_clouds, through: :clusters
  has_many :projects, through: :clusters
  has_many :add_ons, through: :clusters
  has_many :services, through: :projects
  has_many :providers, through: :users
  has_many :favorites, dependent: :destroy

  def github_username
    return unless github_provider

    JSON.parse(github_provider.auth)["info"]["nickname"]
  end

  def github_access_token
    github_provider&.access_token
  end

  def github_provider
    @_github_account ||= owner.providers.find_by(provider: "github")
  end

  def gitlab_username
    return unless gitlab_provider

    JSON.parse(gitlab_provider.auth)["info"]["nickname"]
  end

  def gitlab_access_token
    gitlab_provider&.access_token
  end

  def gitlab_provider
    @_gitlab_provider ||= owner.providers.find_by(provider: "gitlab")
  end

  def sso_enabled?
    sso_provider&.enabled?
  end

  def custom_login?
    sso_enabled?
  end
end
