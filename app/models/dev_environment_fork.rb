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
class DevEnvironmentFork < ApplicationRecord
  belongs_to :child_project, class_name: "Project", foreign_key: :child_project_id
  belongs_to :parent_project, class_name: "Project", foreign_key: :parent_project_id

  validates :child_project_id, uniqueness: true
  validates :parent_project_id, presence: true

end
