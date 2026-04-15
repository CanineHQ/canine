# == Schema Information
#
# Table name: development_environment_configurations
#
#  id                       :bigint           not null, primary key
#  dockerfile_path          :string
#  enabled                  :boolean          default(FALSE), not null
#  workspace_mount_path     :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  cluster_id               :bigint
#  git_provider_id          :bigint
#  intelligence_provider_id :bigint
#  project_id               :bigint           not null
#
# Indexes
#
#  idx_on_git_provider_id_d487b7dad5                           (git_provider_id)
#  idx_on_intelligence_provider_id_27de8a8dd1                  (intelligence_provider_id)
#  index_development_environment_configurations_on_cluster_id  (cluster_id)
#  index_development_environment_configurations_on_project_id  (project_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (git_provider_id => providers.id)
#  fk_rails_...  (intelligence_provider_id => providers.id)
#  fk_rails_...  (project_id => projects.id)
#
FactoryBot.define do
  factory :development_environment_configuration do
    project
    cluster { project.cluster }
    dockerfile_path { "./Dockerfile.dev" }
    workspace_mount_path { "/app" }
    enabled { true }
  end
end
