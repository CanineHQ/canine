# == Schema Information
#
# Table name: sso_providers
#
#  id                     :bigint           not null, primary key
#  configuration_type     :string           not null
#  enabled                :boolean          default(TRUE), not null
#  name                   :string           not null
#  team_provisioning_mode :integer          not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  configuration_id       :bigint           not null
#
# Indexes
#
#  index_sso_providers_on_account_id     (account_id) UNIQUE
#  index_sso_providers_on_configuration  (configuration_type,configuration_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class SSOProvider < ApplicationRecord
  belongs_to :account
  belongs_to :configuration, polymorphic: true, dependent: :destroy
  has_many :providers, dependent: :nullify

  validates :account_id, uniqueness: true

  enum :team_provisioning_mode, {
    disabled: 0,
    just_in_time: 1
  }, suffix: true


  def ldap?
    configuration_type == "LDAPConfiguration"
  end

  def oidc?
    configuration_type == "OIDCConfiguration"
  end

  def sso_users_count
    providers.joins(:user).distinct.count(:user_id)
  end
end
