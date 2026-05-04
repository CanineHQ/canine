require "rails_helper"

RSpec.describe Projects::DevelopmentEnvironmentConfigurationsController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:user) { account.owner }
  let(:cluster) { create(:cluster, account: account) }
  let(:target_cluster) { create(:cluster, account: account) }
  let(:project) { create(:project, cluster: cluster, account: account) }

  before do
    sign_in user
  end

  describe "POST #create" do
    it "creates a development environment configuration" do
      expect {
        post project_development_environment_configuration_path(project), params: {
          development_environment_configuration: {
            cluster_id: target_cluster.id,
            dockerfile_path: "./Dockerfile.dev",
            workspace_mount_path: "/app",
            enabled: "1"
          }
        }
      }.to change(DevelopmentEnvironmentConfiguration, :count).by(1)

      configuration = project.reload.development_environment_configuration
      expect(configuration.cluster_id).to eq(target_cluster.id)
      expect(configuration.dockerfile_path).to eq("./Dockerfile.dev")
      expect(configuration.workspace_mount_path).to eq("/app")
      expect(configuration.enabled).to be(true)
      expect(response).to redirect_to(edit_project_path(project, anchor: "development-environment"))
    end
  end

  describe "PATCH #update" do
    let!(:configuration) { create(:development_environment_configuration, project: project, enabled: true) }

    it "updates the existing configuration" do
      patch project_development_environment_configuration_path(project), params: {
        development_environment_configuration: {
          cluster_id: target_cluster.id,
          dockerfile_path: "./Dockerfile.dev",
          workspace_mount_path: "/workspace",
          enabled: "0"
        }
      }

      expect(configuration.reload.cluster_id).to eq(target_cluster.id)
      expect(configuration.workspace_mount_path).to eq("/workspace")
      expect(configuration.enabled).to be(false)
      expect(response).to redirect_to(edit_project_path(project, anchor: "development-environment"))
    end
  end

  describe "DELETE #destroy" do
    let!(:configuration) { create(:development_environment_configuration, project: project) }

    it "removes the configuration" do
      expect {
        delete project_development_environment_configuration_path(project)
      }.to change(DevelopmentEnvironmentConfiguration, :count).by(-1)

      expect(response).to redirect_to(edit_project_path(project, anchor: "development-environment"))
    end
  end
end
