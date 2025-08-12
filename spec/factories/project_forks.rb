# == Schema Information
#
# Table name: project_forks
#
#  id                :bigint           not null, primary key
#  number            :string           not null
#  title             :string           not null
#  url               :string           not null
#  user              :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  child_project_id  :bigint           not null
#  external_id       :string           not null
#  parent_project_id :bigint           not null
#
# Indexes
#
#  index_project_forks_on_child_project_id   (child_project_id) UNIQUE
#  index_project_forks_on_parent_project_id  (parent_project_id)
#
# Foreign Keys
#
#  fk_rails_...  (child_project_id => projects.id)
#  fk_rails_...  (parent_project_id => projects.id)
#
FactoryBot.define do
  factory :project_fork do
    child_project { create(:project) }
    parent_project { create(:project) }
    external_id { Faker::Alphanumeric.alphanumeric(number: 10) }
    number { Faker::Alphanumeric.alphanumeric(number: 10) }
    title { Faker::Lorem.sentence }
    url { Faker::Internet.url }
    user { Faker::Internet.username }
  end
end
