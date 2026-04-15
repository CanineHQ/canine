# == Schema Information
#
# Table name: development_environment_configurations
#
#  id                   :bigint           not null, primary key
#  cluster_id           :bigint
#  dockerfile_path      :string
#  enabled              :boolean          default(FALSE), not null
#  workspace_mount_path :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
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
  belongs_to :cluster, optional: true

  validates :project, presence: true
  validates :project_id, uniqueness: true
  validates :cluster, :dockerfile_path, :workspace_mount_path, presence: true, if: :enabled?
  validate :cluster_belongs_to_project_account
  before_validation :default_cluster_from_project, on: :create

  def self.permit_params(params)
    params.permit(:id, :cluster_id, :dockerfile_path, :workspace_mount_path, :enabled)
  end

  private

  def default_cluster_from_project
    self.cluster ||= project&.cluster
  end

  def cluster_belongs_to_project_account
    return if cluster_id.blank? || project.blank?
    return if project.account.clusters.exists?(id: cluster_id)

    errors.add(:cluster_id, "must belong to the same account as the project")
  end
end
