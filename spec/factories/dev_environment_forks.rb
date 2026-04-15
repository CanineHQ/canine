# == Schema Information
#
# Table name: dev_environment_forks
#
#  id                :bigint           not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  child_project_id  :bigint           not null
#  parent_project_id :bigint           not null
#
# Indexes
#
#  index_dev_environment_forks_on_child_project_id   (child_project_id) UNIQUE
#  index_dev_environment_forks_on_parent_project_id  (parent_project_id)
#
# Foreign Keys
#
#  fk_rails_...  (child_project_id => projects.id)
#  fk_rails_...  (parent_project_id => projects.id)
#
FactoryBot.define do
  factory :dev_environment_fork do
    child_project { create(:project) }
    parent_project { create(:project) }
  end
end
