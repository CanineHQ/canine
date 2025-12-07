# == Schema Information
#
# Table name: team_resources
#
#  id                :bigint           not null, primary key
#  resourceable_type :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  resourceable_id   :bigint           not null
#  team_id           :bigint           not null
#
# Indexes
#
#  index_team_resources_on_resourceable           (resourceable_type,resourceable_id)
#  index_team_resources_on_team_and_resourceable  (team_id,resourceable_type,resourceable_id) UNIQUE
#  index_team_resources_on_team_id                (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#
FactoryBot.define do
  factory :team_resource do
    team { nil }
    resourceable { nil }
  end
end
