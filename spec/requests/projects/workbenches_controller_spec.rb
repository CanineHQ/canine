require "rails_helper"

RSpec.describe Projects::WorkbenchesController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }
  let(:user) { account.owner }
  let(:cluster) { create(:cluster, account: account) }
  let(:project) { create(:project, cluster: cluster, account: account) }
  let(:file) { fixture_file_upload("spec/fixtures/files/test_upload.txt", "text/plain") }

  before do
    sign_in user
    allow_any_instance_of(Project).to receive(:development_environment?).and_return(true)
    allow_any_instance_of(Projects::WorkbenchesController).to receive(:fetch_pods).and_return(pods)
  end

  describe "POST #upload" do
    let(:pod_metadata) { OpenStruct.new(name: "my-app-pod-abc123") }
    let(:pod_status) { OpenStruct.new(phase: "Running") }
    let(:pod) { OpenStruct.new(metadata: pod_metadata, status: pod_status) }
    let(:pods) { [ pod ] }

    it "rejects upload when no file is provided" do
      post upload_project_workbench_path(project), params: { pod_name: "my-app-pod-abc123" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to eq("No file provided")
    end

    it "rejects upload with invalid pod name" do
      post upload_project_workbench_path(project), params: { file: file, pod_name: "evil-pod" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to eq("Invalid pod")
    end

    it "rejects upload when no pods are running" do
      allow_any_instance_of(Projects::WorkbenchesController).to receive(:fetch_pods).and_return([])

      post upload_project_workbench_path(project), params: { file: file, pod_name: "my-app-pod-abc123" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to eq("Invalid pod")
    end

    it "uploads file to a valid running pod" do
      kubectl = instance_double(K8::Kubectl)
      allow(K8::Kubectl).to receive(:new).and_return(kubectl)
      allow(kubectl).to receive(:call).and_return("")

      post upload_project_workbench_path(project), params: { file: file, pod_name: "my-app-pod-abc123" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["path"]).to start_with("/tmp/uploads/")
      expect(response.parsed_body["path"]).to end_with("_test_upload.txt")
      expect(kubectl).to have_received(:call).twice
    end
  end
end
