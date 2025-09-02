# == Schema Information
#
# Table name: projects
#
#  id                             :bigint           not null, primary key
#  autodeploy                     :boolean          default(TRUE), not null
#  branch                         :string           default("main"), not null
#  canine_config                  :jsonb
#  container_registry_url         :string
#  docker_build_context_directory :string           default("."), not null
#  docker_command                 :string
#  dockerfile_path                :string           default("./Dockerfile"), not null
#  name                           :string           not null
#  postdeploy_command             :text
#  postdestroy_command            :text
#  predeploy_command              :text
#  predestroy_command             :text
#  project_fork_status            :integer          default("disabled")
#  repository_url                 :string           not null
#  status                         :integer          default("creating"), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  cluster_id                     :bigint           not null
#  project_fork_cluster_id        :bigint
#
# Indexes
#
#  index_projects_on_cluster_id  (cluster_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (project_fork_cluster_id => clusters.id)
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
  has_one :build_configuration, dependent: :destroy

  has_one :child_fork, class_name: "ProjectFork", foreign_key: :child_project_id, dependent: :destroy
  has_many :forks, class_name: "ProjectFork", foreign_key: :parent_project_id, dependent: :destroy
  has_one :project_fork_cluster, class_name: "Cluster", foreign_key: :id, primary_key: :project_fork_cluster_id

  validates :name, presence: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "must be lowercase, numbers, and hyphens only" }
  validates :branch, presence: true
  validates :repository_url, presence: true,
                            format: {
                              with: /\A[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]\/[a-zA-Z0-9._-]+\z/,
                              message: "must be in the format 'owner/repository'"
                            }
  validates :project_credential_provider, presence: true
  validates_presence_of :project_fork_cluster_id, unless: :forks_disabled?
  validate :project_fork_cluster_id_is_owned_by_account
  validates_presence_of :build_configuration, if: :git?

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
  enum :project_fork_status, {
    disabled: 0,
    manually_create: 1
  }, prefix: :forks
  delegate :git?, :github?, :gitlab?, to: :project_credential_provider
  delegate :container_registry?, to: :project_credential_provider

  def project_fork_cluster_id_is_owned_by_account
    if project_fork_cluster_id.present? && !account.clusters.exists?(id: project_fork_cluster_id)
      errors.add(:project_fork_cluster_id, "must be owned by the account")
    end
  end

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

  def link_to_view
    if forked?
      if github?
        "https://github.com/#{repository_url}/pull/#{child_fork.number}"
      elsif gitlab?
        "https://gitlab.com/#{repository_url}/merge_requests/#{child_fork.number}"
      end
    else
      if github?
        "https://github.com/#{repository_url}"
      elsif gitlab?
        "https://gitlab.com/#{repository_url}"
      else
        "https://hub.docker.com/r/#{repository_url}"
      end
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

  def container_image_reference
    result = Projects::DetermineContainerImageReference.execute(project: self)
    raise result.message if result.failure?
    result.container_image_reference
  end

  # Forks
  def parent_project
    if child_fork.present?
      child_fork.parent_project
    else
      raise "Project is not a forked project"
    end
  end

  def show_fork_options?
    !forked? && git?
  end

  def can_fork?
    show_fork_options? && !forks_disabled?
  end

  def forked?
    child_fork.present?
  end

  def build_provider
    if build_configuration.present?
      build_configuration.provider
    else
      project_credential_provider.provider
    end
  end
end
