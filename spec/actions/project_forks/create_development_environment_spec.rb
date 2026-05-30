require 'rails_helper'

RSpec.describe ProjectForks::CreateDevelopmentEnvironment do
  let(:account) { create(:account) }
  let(:user) { account.owner }
  let(:cluster) { create(:cluster, account:) }
  let(:parent_project) { create(:project, account:, cluster:) }
  let(:provider) { create(:provider, :github, user:) }
  let!(:project_credential_provider) { create(:project_credential_provider, project: parent_project, provider:) }
  let!(:build_config) { create(:build_configuration, project: parent_project, build_type: "dockerfile", dockerfile_path: "./Dockerfile") }
  let!(:service) { create(:service, project: parent_project) }
  let(:git_provider) { create(:provider, :github, user:, access_token: "git-token-123") }

  let!(:dev_env_config) do
    create(:development_environment_configuration,
      project: parent_project,
      cluster:,
      dockerfile_path: "./Dockerfile.dev",
      workspace_mount_path: "/app"
    )
  end

  subject(:result) { described_class.call(parent_project:, current_user: user, git_provider:) }

  it "creates a child project, development environment record, and assigns ownership" do
    expect(result).to be_success
    expect(result.project).to be_persisted
    expect(result.project.cluster).to eq(cluster)

    dev_env = result.development_environment
    expect(dev_env).to be_persisted
    expect(dev_env.parent_project).to eq(parent_project)
    expect(dev_env.child_project).to eq(result.project)
    expect(dev_env.git_provider).to eq(git_provider)
    expect(dev_env.created_by).to eq(user)
  end

  it "initializes services and env vars on the child project" do
    expect(result.project.services.count).to be >= 1
    expect(result.project.environment_variables.where(name: "GIT_ACCESS_TOKEN")).to exist
    expect(result.project.volumes.where(mount_path: "/app")).to exist
  end

  it "raises when no development environment configuration exists" do
    dev_env_config.destroy!

    expect {
      described_class.call(parent_project: parent_project.reload, current_user: user, git_provider:)
    }.to raise_error(/No development environment configuration found/)
  end
end
