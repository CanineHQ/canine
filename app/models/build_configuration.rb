# == Schema Information
#
# Table name: build_configurations
#
#  id               :bigint           not null, primary key
#  driver           :integer          not null
#  image_repository :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  build_cloud_id   :bigint
#  project_id       :bigint           not null
#  provider_id      :bigint           not null
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
  DEFAULT_BUILDER = Rails.application.config.cloud_mode ? :cloud : :docker
  BUILDER_OPTIONS = if Rails.application.config.local_mode
    [ :docker, :k8s ]
  elsif Rails.application.config.cloud_mode
    [ :cloud, :k8s ]
  elsif Rails.application.config.cluster_mode
    [ :k8s ]
  end
  belongs_to :project
  belongs_to :build_cloud, optional: true
  belongs_to :provider

  validates_presence_of :project, :provider, :driver
  validates_presence_of :image_repository
  validates :image_repository, format: {
    with: /\A[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]\/[a-zA-Z0-9._-]+\z/,
    message: "must be in the format 'namespace/repo'"
  }

  def self.permit_params(params)
    params.permit(:image_repository, :driver, :build_cloud_id, :provider_id)
  end

  enum :driver, {
    cloud: 0,
    docker: 1,
    k8s: 2
  }
  validates_presence_of :build_cloud, if: -> { driver == 'k8s' }

  def container_image_reference
    tag = project.git? ? project.branch.gsub('/', '-') : 'latest'
    "#{provider.registry_base_url}/#{image_repository}:#{tag}"
  end
end
