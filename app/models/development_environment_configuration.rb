# == Schema Information
#
# Table name: development_environment_configurations
#
#  id                   :bigint           not null, primary key
#  dockerfile_path      :string           not null
#  enabled              :boolean          default(FALSE), not null
#  workspace_mount_path :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  cluster_id           :bigint           not null
#  project_id           :bigint           not null
#
# Indexes
#
#  index_development_environment_configurations_on_cluster_id  (cluster_id)
#  index_development_environment_configurations_on_project_id  (project_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (project_id => projects.id)
#
class DevelopmentEnvironmentConfiguration < ApplicationRecord
  belongs_to :project
  belongs_to :cluster
  validates :project, presence: true
  validates :project_id, uniqueness: true
  validates :dockerfile_path, :workspace_mount_path, presence: true
  validate :cluster_belongs_to_project_account

  def self.permit_params(params)
    params.permit(
      :id,
      :dockerfile_path,
      :workspace_mount_path,
      :enabled,
    )
  end

  private

  def cluster_belongs_to_project_account
    return if cluster_id.blank? || project.blank?
    return if project.account.clusters.exists?(id: cluster_id)

    errors.add(:cluster_id, "must belong to the same account as the project")
  end
end
