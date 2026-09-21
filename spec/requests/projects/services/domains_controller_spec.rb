# frozen_string_literal: true

require "rails_helper"

RSpec.describe Projects::Services::DomainsController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:user) { account.owner }
  let(:cluster) { create(:cluster, account: account) }
  let(:project) { create(:project, cluster: cluster, account: account) }
  let(:service) { create(:service, project: project, status: :healthy) }

  before do
    sign_in user
  end

  describe "DELETE #destroy" do
    let!(:domain) { create(:domain, service: service, domain_name: "custom.example.com") }

    it "destroys the domain, marks the service as updated, and responds to turbo_stream" do
      expect {
        delete project_service_domain_path(project, service, domain), as: :turbo_stream
      }.to change(Domain, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(target="service/#{service.id}/domains"))
      expect(service.reload).to be_updated
    end

    it "destroys the domain and renders partial when requested as html" do
      expect {
        delete project_service_domain_path(project, service, domain)
      }.to change(Domain, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(id="service/#{service.id}/domains"))
      expect(service.reload).to be_updated
    end

    it "fails with 404 when domain belongs to a different service" do
      other_service = create(:service, project: project)
      other_domain = create(:domain, service: other_service)

      expect {
        delete project_service_domain_path(project, service, other_domain)
      }.not_to change(Domain, :count)

      expect(response).to redirect_to(root_path)
    end
  end
end
