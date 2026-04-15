# == Schema Information
#
# Table name: development_environment_configurations
#
#  id                   :bigint           not null, primary key
#  dockerfile_path      :string
#  enabled              :boolean          default(FALSE), not null
#  workspace_mount_path :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  project_id           :bigint           not null
#
# Indexes
#
#  index_development_environment_configurations_on_project_id  (project_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
class DevelopmentEnvironmentConfiguration < ApplicationRecord
  belongs_to :project

  validates :project, presence: true
  validates :project_id, uniqueness: true
  validates :dockerfile_path, :workspace_mount_path, presence: true, if: :enabled?

  def self.permit_params(params)
    params.permit(:id, :dockerfile_path, :workspace_mount_path, :enabled)
  end
end
