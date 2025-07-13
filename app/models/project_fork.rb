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
class ProjectFork < ApplicationRecord
  belongs_to :child_project, class_name: "Project", foreign_key: :child_project_id
  belongs_to :parent_project, class_name: "Project", foreign_key: :parent_project_id
  validates :external_id, presence: true
  validates :child_project_id, uniqueness: true
  validates :parent_project_id, presence: true

  def urls
    child_project.services.web_service.map(&:internal_url)
  end
end
