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
  validates :project_credential_provider, presence: true

  validate :name_is_unique_to_cluster, on: :create
  after_save_commit do
    broadcast_replace_to [ self, :status ], target: dom_id(self, :status), partial: "projects/status", locals: { project: self }
  end

  after_destroy_commit do
    broadcast_remove_to [ :projects, self.account ], target: dom_id(self, :index)
  end

  enum :status, {
    creating: 0,
    deployed: 1,
    destroying: 2
  }
  delegate :git?, :github?, :gitlab?, to: :project_credential_provider
  delegate :docker_hub?, to: :project_credential_provider

  def name_is_unique_to_cluster
    if cluster.namespaces.include?(name)
      errors.add(:name, "must be unique to this cluster")
    end
  end

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
    if github?
      "https://github.com/#{repository_url}"
    elsif gitlab?
      "https://gitlab.com/#{repository_url}"
    else
      "https://hub.docker.com/r/#{repository_url}"
    end
  end

  def provider
    project_credential_provider&.provider
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

  def container_registry_url
    container_registry = self.attributes["container_registry_url"].presence || repository_url
    tag = docker_hub? ? 'latest' : branch.gsub('/', '-') # Docker Hub uses latest, others use branch name
    
    if github?
      "ghcr.io/#{container_registry}:#{tag}"
    elsif gitlab?
      "registry.gitlab.com/#{container_registry}:#{tag}"
    else
      "docker.io/#{container_registry}:#{tag}"
    end
  end
end
