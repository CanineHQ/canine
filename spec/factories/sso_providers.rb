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
FactoryBot.define do
  factory :sso_provider do
    account { nil }
    configuration { nil }
    name { "MyString" }
    enabled { false }
  end
end
