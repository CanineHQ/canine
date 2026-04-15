require "rails_helper"

RSpec.describe Projects::DevelopmentEnvironmentConfigurationsController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:user) { account.owner }
  let(:cluster) { create(:cluster, account: account) }
  let(:project) { create(:project, cluster: cluster) }

  before do
    sign_in user
  end

  describe "POST #create" do
    it "creates a development environment configuration" do
      expect {
        post project_development_environment_configuration_path(project), params: {
          development_environment_configuration: {
            dockerfile_path: "./Dockerfile.dev",
            workspace_mount_path: "/app",
            enabled: "1"
          }
        }
      }.to change(DevelopmentEnvironmentConfiguration, :count).by(1)

      configuration = project.reload.development_environment_configuration
      expect(configuration.dockerfile_path).to eq("./Dockerfile.dev")
      expect(configuration.workspace_mount_path).to eq("/app")
      expect(configuration.enabled).to be(true)
      expect(response).to redirect_to(edit_project_path(project))
    end

    it "re-renders the panel for turbo frame requests" do
      post project_development_environment_configuration_path(project),
           params: {
             development_environment_configuration: {
               dockerfile_path: "./Dockerfile.dev",
               workspace_mount_path: "/app",
               enabled: "1"
             }
           },
           headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(project, :development_environment_configuration) }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(project, :development_environment_configuration))
      expect(response.body).to include("Development environment configuration saved.")
    end
  end

  describe "PATCH #update" do
    let!(:configuration) { create(:development_environment_configuration, project: project, enabled: true) }

    it "updates the existing configuration" do
      patch project_development_environment_configuration_path(project), params: {
        development_environment_configuration: {
          dockerfile_path: "./Dockerfile.dev",
          workspace_mount_path: "/workspace",
          enabled: "0"
        }
      }

      expect(configuration.workspace_mount_path).to eq("/workspace")
      expect(configuration.enabled).to be(false)
      expect(response).to redirect_to(edit_project_path(project))
    end
  end

  describe "DELETE #destroy" do
    let!(:configuration) { create(:development_environment_configuration, project: project) }

    it "removes the configuration" do
      expect {
        delete project_development_environment_configuration_path(project)
      }.to change(DevelopmentEnvironmentConfiguration, :count).by(-1)

      expect(response).to redirect_to(edit_project_path(project))
    end

    it "re-renders the cleared panel for turbo frame requests" do
      delete project_development_environment_configuration_path(project),
             headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(project, :development_environment_configuration) }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Development environment configuration removed.")
    end
  end
end
