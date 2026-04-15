# == Schema Information
#
# Table name: project_forks
#
#  id                :bigint           not null, primary key
#  fork_type         :integer          default(0), not null
#  number            :string
#  title             :string
#  url               :string
#  user              :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  child_project_id  :bigint           not null
#  external_id       :string
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
    fork_type { :review_app }
    external_id { Faker::Alphanumeric.alphanumeric(number: 10) }
    number { Faker::Alphanumeric.alphanumeric(number: 10) }
    title { Faker::Lorem.sentence }
    url { Faker::Internet.url }
    user { Faker::Internet.username }

    trait :dev_environment do
      fork_type { :dev_environment }
      external_id { nil }
      number { nil }
      title { nil }
      url { nil }
      user { nil }
    end
  end
end
