# == Schema Information
#
# Table name: development_environments
#
#  id                :bigint           not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  child_project_id  :bigint           not null
#  created_by_id     :bigint           not null
#  git_provider_id   :bigint           not null
#  parent_project_id :bigint           not null
#
# Indexes
#
#  index_dev_envs_on_git_provider_id                    (git_provider_id)
#  index_development_environments_on_child_project_id   (child_project_id) UNIQUE
#  index_development_environments_on_created_by_id      (created_by_id)
#  index_development_environments_on_parent_project_id  (parent_project_id)
#
# Foreign Keys
#
#  fk_rails_...  (child_project_id => projects.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (git_provider_id => providers.id)
#  fk_rails_...  (parent_project_id => projects.id)
#
FactoryBot.define do
  factory :development_environment do
    child_project { create(:project) }
    parent_project { create(:project) }
    git_provider { create(:provider, :github) }
    created_by { git_provider.user }
  end
end
