# == Schema Information
#
# Table name: projects
#
#  id                             :bigint           not null, primary key
#  autodeploy                     :boolean          default(TRUE), not null
#  branch                         :string           default("main"), not null
#  docker_build_context_directory :string           default("."), not null
#  docker_command                 :string
#  dockerfile_path                :string           default("./Dockerfile"), not null
#  name                           :string           not null
#  predeploy_command              :string
#  repository_url                 :string           not null
#  status                         :integer          default("creating"), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  cluster_id                     :bigint           not null
#
# Indexes
#
#  index_projects_on_cluster_id  (cluster_id)
#  index_projects_on_name        (name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#
class Project < ApplicationRecord
  broadcasts_refreshes
  belongs_to :cluster
  has_one :user, through: :cluster
  has_many :services, dependent: :destroy
  has_many :environment_variables, dependent: :destroy
  has_many :builds, dependent: :destroy
  has_many :deployments, through: :builds
  has_many :domains, through: :services
  validates :name, presence: true,
                   format: { with: /\A[a-z0-9_-]+\z/, message: "must be lowercase, numbers, hyphens, and underscores only" }

  enum :status, {
    creating: 0,
    deployed: 1
  }

  def current_deployment
    deployments.order(created_at: :desc).where(status: :completed).first
  end

  def last_deployed_at
    deployments.order(created_at: :desc).first&.created_at
  end

  def repository_name
    repository_url.split("/").last
  end

  def full_repository_url
    "https://github.com/#{repository_url}"
  end

  def container_registry_url
    "ghcr.io/#{repository_url}:latest"
  end
end
