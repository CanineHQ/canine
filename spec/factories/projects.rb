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
FactoryBot.define do
  factory :project do
    cluster
    account
    sequence(:name) { |n| "example-project-#{n}" }
    repository_url { "owner/repository" }
    status { :creating }
    autodeploy { true }
    branch { "main" }
    dockerfile_path { "./Dockerfile" }
    docker_build_context_directory { "." }

    after(:build) do |project|
      provider = create(:provider, :github)
      project.project_credential_provider ||= build(:project_credential_provider, project: project, provider: provider)
    end

    trait :github do
      after(:build) do |project|
        provider = create(:provider, :github)
        project.project_credential_provider = build(:project_credential_provider, project: project, provider: provider)
      end
    end

    trait :container_registry do
      after(:build) do |project|
        provider = create(:provider, :container_registry)
        project.project_credential_provider = build(:project_credential_provider, project: project, provider: provider)
      end
    end
  end
end
