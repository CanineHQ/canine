# == Schema Information
#
# Table name: projects
#
#  id                             :bigint           not null, primary key
#  autodeploy                     :boolean          default(TRUE), not null
#  branch                         :string           default("main"), not null
#  container_registry_url         :string
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
  has_one :account, through: :cluster
  has_many :users, through: :account
  has_many :services, dependent: :destroy
  has_many :environment_variables, dependent: :destroy
  has_many :builds, dependent: :destroy
  has_many :deployments, through: :builds
  has_many :domains, through: :services
  has_many :events, dependent: :destroy
  has_many :volumes, dependent: :destroy

  has_one :project_credential_provider, dependent: :destroy
  validates :name, presence: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "must be lowercase, numbers, and hyphens only" }
  validates :repository_url, presence: true,
                            format: {
                              with: /\A[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]\/[a-zA-Z0-9._-]+\z/,
                              message: "must be in the format 'owner/repository'"
                            }

  validates_uniqueness_of :name, scope: :cluster_id

  enum :status, {
    creating: 0,
    deployed: 1,
    destroying: 2
  }

  def current_deployment
    deployments.order(created_at: :desc).where(status: :completed).first
  end

  def last_build
    builds.order(created_at: :desc).first
  end

  def last_deployment
    deployments.order(created_at: :desc).first
  end

  def last_build
    builds.order(created_at: :desc).first
  end

  def last_deployment_at
    last_deployment&.created_at
  end

  def repository_name
    repository_url.split("/").last
  end

  def full_repository_url
    "https://github.com/#{repository_url}"
  end

  def github_username
    project_credential_provider&.github_access_token || account.github_access_token
  end

  def github_access_token
    project_credential_provider&.github_access_token || account.github_access_token
  end

  def container_registry_url
    container_registry = self.attributes["container_registry_url"] || repository_url
    "ghcr.io/#{container_registry}:latest"
  end

  def deployable?
    services.any?
  end

  def has_updates?
    services.any?(&:updated?) || services.any?(&:pending?)
  end

  def updated!
    services.each(&:updated!)
  end
end
