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
class DevelopmentEnvironment < ApplicationRecord
  belongs_to :child_project, class_name: "Project", foreign_key: :child_project_id
  belongs_to :parent_project, class_name: "Project", foreign_key: :parent_project_id
  belongs_to :git_provider, class_name: "Provider"
  belongs_to :created_by, class_name: "User"

  validates :child_project_id, uniqueness: true
  validates :parent_project_id, presence: true
end
