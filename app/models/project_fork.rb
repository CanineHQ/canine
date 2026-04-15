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
class ProjectFork < ApplicationRecord
  belongs_to :child_project, class_name: "Project", foreign_key: :child_project_id
  belongs_to :parent_project, class_name: "Project", foreign_key: :parent_project_id

  enum :fork_type, { review_app: 0, dev_environment: 1 }

  validates :external_id, presence: true, if: :review_app?
  validates :child_project_id, uniqueness: true
  validates :parent_project_id, presence: true

  scope :review_apps, -> { where(fork_type: :review_app) }
  scope :dev_environments, -> { where(fork_type: :dev_environment) }

  def urls
    child_project.services.web_service.map(&:internal_url)
  end
end
