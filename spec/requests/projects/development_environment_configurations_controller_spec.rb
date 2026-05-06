require "rails_helper"

RSpec.describe Projects::DevelopmentEnvironmentConfigurationsController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:user) { account.owner }
  let(:cluster) { create(:cluster, account: account) }
  let(:project) { create(:project, cluster: cluster, account: account) }
  let(:git_provider) { create(:provider, :github, user: user) }

  before do
    sign_in user
  end

  describe "POST #create" do
    it "creates a configuration with the given cluster and git provider" do
      expect {
        post project_development_environment_configuration_path(project), params: {
          development_environment_configuration: {
            cluster_id: cluster.id,
            git_provider_id: git_provider.id,
            dockerfile_path: "./Dockerfile.dev",
            workspace_mount_path: "/app",
            enabled: "1"
          }
        }
      }.to change(DevelopmentEnvironmentConfiguration, :count).by(1)

      configuration = project.reload.development_environment_configuration
      expect(configuration.cluster).to eq(cluster)
      expect(configuration.git_provider).to eq(git_provider)
      expect(configuration.dockerfile_path).to eq("./Dockerfile.dev")
      expect(configuration.workspace_mount_path).to eq("/app")
      expect(response).to redirect_to(edit_project_path(project, anchor: "development-environment"))
    end

    it "returns 404 when cluster belongs to another account" do
      other_cluster = create(:cluster)

      expect {
        post project_development_environment_configuration_path(project), params: {
          development_environment_configuration: {
            cluster_id: other_cluster.id,
            git_provider_id: git_provider.id,
            dockerfile_path: "./Dockerfile.dev",
            workspace_mount_path: "/app",
            enabled: "1"
          }
        }
      }.not_to change(DevelopmentEnvironmentConfiguration, :count)

      expect(response).to redirect_to(root_path)
    end

    it "returns 404 when git provider belongs to another user" do
      other_provider = create(:provider, :github)

      expect {
        post project_development_environment_configuration_path(project), params: {
          development_environment_configuration: {
            cluster_id: cluster.id,
            git_provider_id: other_provider.id,
            dockerfile_path: "./Dockerfile.dev",
            workspace_mount_path: "/app",
            enabled: "1"
          }
        }
      }.not_to change(DevelopmentEnvironmentConfiguration, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH #update" do
    let!(:configuration) { create(:development_environment_configuration, project: project, cluster: cluster, git_provider: git_provider, enabled: true) }

    it "updates the existing configuration" do
      patch project_development_environment_configuration_path(project), params: {
        development_environment_configuration: {
          cluster_id: cluster.id,
          git_provider_id: git_provider.id,
          dockerfile_path: "./Dockerfile.dev",
          workspace_mount_path: "/workspace",
          enabled: "0"
        }
      }

      expect(configuration.reload.workspace_mount_path).to eq("/workspace")
      expect(configuration.enabled).to be(false)
      expect(response).to redirect_to(edit_project_path(project, anchor: "development-environment"))
    end

    it "returns 404 when cluster belongs to another account" do
      other_cluster = create(:cluster)

      patch project_development_environment_configuration_path(project), params: {
        development_environment_configuration: {
          cluster_id: other_cluster.id,
          git_provider_id: git_provider.id,
          dockerfile_path: "./Dockerfile.dev",
          workspace_mount_path: "/app",
          enabled: "1"
        }
      }

      expect(response).to redirect_to(root_path)
    end

    it "returns 404 when git provider belongs to another user" do
      other_provider = create(:provider, :github)

      patch project_development_environment_configuration_path(project), params: {
        development_environment_configuration: {
          cluster_id: cluster.id,
          git_provider_id: other_provider.id,
          dockerfile_path: "./Dockerfile.dev",
          workspace_mount_path: "/app",
          enabled: "1"
        }
      }

      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE #destroy" do
    let!(:configuration) { create(:development_environment_configuration, project: project, cluster: cluster) }

    it "removes the configuration" do
      expect {
        delete project_development_environment_configuration_path(project)
      }.to change(DevelopmentEnvironmentConfiguration, :count).by(-1)

      expect(response).to redirect_to(edit_project_path(project, anchor: "development-environment"))
    end
  end
end
