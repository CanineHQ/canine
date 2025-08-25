# == Schema Information
#
# Table name: accounts
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  owner_id   :bigint
#
# Indexes
#
#  index_accounts_on_owner_id  (owner_id)
#
# Foreign Keys
#
#  fk_rails_...  (owner_id => users.id)
#
class Account < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :account_users, dependent: :destroy
  has_many :users, through: :account_users
  has_one :stack_manager, dependent: :destroy

  has_many :clusters, dependent: :destroy
  has_many :build_clouds, through: :clusters
  has_many :projects, through: :clusters
  has_many :add_ons, through: :clusters
  has_many :services, through: :projects

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
end
