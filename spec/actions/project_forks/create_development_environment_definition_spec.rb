require 'rails_helper'

RSpec.describe ProjectForks::CreateDevelopmentEnvironmentDefinition do
  let(:account) { create(:account) }
  let(:parent_project) { create(:project, account:) }
  let(:provider) { create(:provider, :github, user: account.owner) }
  let!(:project_credential_provider) { create(:project_credential_provider, project: parent_project, provider:) }
  let!(:build_config) { create(:build_configuration, project: parent_project, build_type: "dockerfile", dockerfile_path: "./Dockerfile") }
  let!(:service) { create(:service, project: parent_project, domains: [ create(:domain) ]) }

  let(:git_provider) { create(:provider, :github, user: account.owner, access_token: "git-token-123") }

  let!(:development_environment_configuration) do
    create(:development_environment_configuration,
      project: parent_project,
      dockerfile_path: "./Dockerfile.dev",
      workspace_mount_path: "/app",
      git_provider: git_provider
    )
  end

  subject(:result) { described_class.execute(parent_project: parent_project) }
  let(:definition) { result.definition }

  it "generates a unique dev environment name and substitutes the dev dockerfile" do
    expect(definition["project"]["name"]).to match(/\A#{parent_project.name}-dev-[a-f0-9]{8}\z/)
    expect(definition["build_configuration"]["dockerfile_path"]).to eq "./Dockerfile.dev"
  end

  it "strips domains from services" do
    definition["services"].each do |s|
      expect(s).not_to have_key("domains")
    end
  end

  it "injects rover environment variables" do
    env_vars = definition["environment_variables"]
    env_names = env_vars.map { |e| e["name"] }

    expect(env_names).to include("ROVER_WORKSPACE_DIR", "ROVER_GIT_REPOSITORY_URL", "ROVER_GIT_ACCESS_TOKEN")
    expect(env_vars.find { |e| e["name"] == "ROVER_WORKSPACE_DIR" }["value"]).to eq "/app"
    expect(env_vars.find { |e| e["name"] == "ROVER_GIT_ACCESS_TOKEN" }["storage_type"]).to eq "secret"
  end

  it "creates rover-home and rover-workspace volumes with matching suffix" do
    project_name = definition["project"]["name"]
    suffix = project_name.split("-").last

    volumes = definition["volumes"]
    home_vol = volumes.find { |v| v["mount_path"] == "/home/rover" }
    workspace_vol = volumes.find { |v| v["mount_path"] == "/app" }

    expect(home_vol["name"]).to eq "rover-home-#{suffix}"
    expect(home_vol["size"]).to eq "1Gi"
    expect(workspace_vol["name"]).to eq "rover-workspace-#{suffix}"
    expect(workspace_vol["size"]).to eq "5Gi"
  end
end
