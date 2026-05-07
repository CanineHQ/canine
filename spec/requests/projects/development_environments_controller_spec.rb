require "rails_helper"

RSpec.describe Projects::DevelopmentEnvironmentsController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:user) { account.owner }
  let(:cluster) { create(:cluster, account: account) }
  let(:project) { create(:project, cluster: cluster, account: account) }
  let!(:configuration) { create(:development_environment_configuration, project: project, cluster: cluster, enabled: true) }

  before { sign_in user }

  describe "POST #create" do
    it "returns 404 when git provider belongs to another user" do
      other_provider = create(:provider, :github)

      expect {
        post project_development_environments_path(project), params: { git_provider_id: other_provider.id }
      }.not_to change(DevelopmentEnvironment, :count)

      expect(response).to redirect_to(root_path)
    end
  end
end
