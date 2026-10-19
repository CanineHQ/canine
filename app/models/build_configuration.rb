# == Schema Information
#
# Table name: build_configurations
#
#  id                     :bigint           not null, primary key
#  build_type             :integer          not null
#  buildpack_base_builder :string
#  cluster_registry       :boolean          default(FALSE), not null
#  context_directory      :string           default("./"), not null
#  dockerfile_path        :string           default("./Dockerfile"), not null
#  driver                 :integer          not null
#  image_repository       :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  build_cloud_id         :bigint
#  project_id             :bigint           not null
#  provider_id            :bigint
#
# Indexes
#
#  index_build_configurations_on_build_cloud_id  (build_cloud_id)
#  index_build_configurations_on_project_id      (project_id)
#  index_build_configurations_on_provider_id     (provider_id)
#
# Foreign Keys
#
#  fk_rails_...  (build_cloud_id => build_clouds.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (provider_id => providers.id)
#
class BuildConfiguration < ApplicationRecord
  DEFAULT_BUILDER = if Rails.application.config.cloud_mode
    :cloud
  elsif Rails.application.config.cluster_mode
    :k8s
  else
    :docker
  end
  BUILDER_OPTIONS = if Rails.application.config.local_mode
    [ :docker, :k8s ]
  elsif Rails.application.config.cloud_mode
    [ :cloud, :k8s ]
  elsif Rails.application.config.cluster_mode
    [ :k8s ]
  end
  belongs_to :project
  belongs_to :build_cloud, optional: true
  belongs_to :provider, optional: true
  has_many :build_packs, -> { order(:build_order) }, dependent: :destroy

  validates_presence_of :project, :driver
  validates_presence_of :provider, unless: :cluster_registry?
  validate :cluster_registry_supported, if: :cluster_registry?
  validates_presence_of :image_repository
  validates :image_repository, format: {
    with: /\A[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]\/[a-zA-Z0-9._-]+(\/[a-zA-Z0-9._-]+)*\z/,
    message: "must be in the format 'namespace/repo' or 'namespace/repo/subpath'"
  }

  def self.permit_params(params)
    params.permit(:image_repository, :driver, :build_cloud_id, :provider_id, :context_directory, :dockerfile_path, :build_type, :buildpack_base_builder, :cluster_registry)
  end

  def self.available_buildpacks
    packs_file = Rails.root.join("resources", "build_packs", "packs.yaml")
    YAML.load_file(packs_file)
  end

  enum :build_type, {
    dockerfile: 0,
    buildpacks: 1
  }

  enum :driver, {
    cloud: 0,
    docker: 1,
    k8s: 2
  }
  validates_presence_of :build_cloud, if: -> { driver == 'k8s' }

  def registry
    ClusterRegistry.new(project.cluster) if cluster_registry?
  end

  # The reference the cluster pulls the image by
  def container_image_reference
    cluster_registry? ? registry.pull_reference(image_name) : "#{provider.registry_base_url}/#{image_name}"
  end

  # The reference builds push the image to
  def push_image_reference
    cluster_registry? ? registry.push_reference(image_name) : container_image_reference
  end

  private

  def image_name
    tag = project.git? ? project.branch.gsub('/', '-') : 'latest'
    "#{image_repository.downcase}:#{tag}"
  end

  # The registry is only reachable inside its cluster, so the build has to run there too
  def cluster_registry_supported
    errors.add(:cluster_registry, "needs the Kubernetes build driver") unless k8s?
    errors.add(:cluster_registry, "doesn't support buildpacks yet") if buildpacks?
    if build_cloud && project && build_cloud.cluster_id != project.cluster_id
      errors.add(:cluster_registry, "needs the build cloud on the project's cluster")
    end
    errors.add(:cluster_registry, "isn't installed on this cluster") if project && !registry.installed?
  end
end
