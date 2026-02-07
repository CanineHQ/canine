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
#  dockerfile_path                :string           default("./Dockerfile"), not null
#  managed_namespace              :boolean          default(TRUE)
#  name                           :string           not null
#  namespace                      :string           not null
#  postdeploy_command             :text
#  postdestroy_command            :text
#  predeploy_command              :text
#  predestroy_command             :text
#  project_fork_status            :integer          default("disabled")
#  repository_url                 :string           not null
#  slug                           :string           not null
#  status                         :integer          default("creating"), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  cluster_id                     :bigint           not null
#  current_deployment_id          :bigint
#  project_fork_cluster_id        :bigint
#
# Indexes
#
#  index_projects_on_cluster_id             (cluster_id)
#  index_projects_on_current_deployment_id  (current_deployment_id)
#  index_projects_on_name                   (name)
#  index_projects_on_slug                   (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (current_deployment_id => deployments.id) ON DELETE => nullify
#  fk_rails_...  (project_fork_cluster_id => clusters.id)
#
FactoryBot.define do
  factory :project do
    cluster
    account
    sequence(:name) { |n| "example-project-#{n}" }
    sequence(:namespace) { |n| "example-project-#{n}" }
    managed_namespace { true }
    repository_url { "owner/repository" }
    status { :creating }
    autodeploy { true }
    branch { "main" }
    dockerfile_path { "./Dockerfile" }
    docker_build_context_directory { "." }

    after(:build) do |project|
      provider = create(:provider, :github)
      project.build_configuration ||= build(:build_configuration, project: project, provider: provider, image_repository: project.repository_url)
      project.project_credential_provider ||= build(:project_credential_provider, project: project, provider: provider)
      project.deployment_configuration ||= build(:deployment_configuration, project: project)
    end

    trait :github do
      after(:build) do |project|
        provider = create(:provider, :github)
        project.build_configuration ||= build(:build_configuration, project: project, provider: provider, image_repository: project.repository_url)
        project.project_credential_provider = build(:project_credential_provider, project: project, provider: provider)
        project.deployment_configuration ||= build(:deployment_configuration, project: project)
      end
    end

    trait :gitlab do
      after(:build) do |project|
        provider = create(:provider, :gitlab)
        project.build_configuration ||= build(:build_configuration, project: project, provider: provider, image_repository: project.repository_url)
        project.project_credential_provider = build(:project_credential_provider, project: project, provider: provider)
        project.deployment_configuration ||= build(:deployment_configuration, project: project)
      end
    end

    trait :container_registry do
      after(:build) do |project|
        provider = create(:provider, :container_registry)
        project.build_configuration ||= build(:build_configuration, project: project, provider: provider, image_repository: project.repository_url)
        project.project_credential_provider = build(:project_credential_provider, project: project, provider: provider)
        project.deployment_configuration ||= build(:deployment_configuration, project: project)
      end
    end
  end
end
