# == Schema Information
#
# Table name: teams
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_teams_on_account_id           (account_id)
#  index_teams_on_account_id_and_name  (account_id,name) UNIQUE
#  index_teams_on_slug                 (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
FactoryBot.define do
  factory :team do
    sequence(:name) { |n| "Team #{n}" }
    account
  end
end
