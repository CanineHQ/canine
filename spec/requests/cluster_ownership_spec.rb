require "rails_helper"

RSpec.describe "Cluster ownership", type: :request do
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:user) { account.owner }
  let(:own_cluster) { create(:cluster, account:) }
  let(:other_cluster) { create(:cluster) } # another account; the user isn't a member

  before do
    sign_in user
    allow(Projects::ValidateGitRepository).to receive(:execute)
    allow(Namespaced::ValidateNamespace).to receive(:execute)
    allow(Projects::RegisterGitWebhook).to receive(:execute)
  end

  it "refuses to create projects or add-ons on another account's cluster" do
    provider = create(:provider, :github, user:)
    post projects_path, params: { project: {
      name: "intruder", branch: "main", cluster_id: other_cluster.id, repository_url: "example/repo",
      container_registry_url: "", project_credential_provider: { provider_id: provider.id }
    } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(Project.where(name: "intruder")).to be_empty

    post add_ons_path, params: { add_on: {
      name: "intruder", cluster_id: other_cluster.id, chart_url: "bitnami/redis", version: "1.0.0", repository_url: "https://charts.bitnami.com/bitnami"
    } }
    expect(AddOn.where(name: "intruder")).to be_empty
    expect(enqueued_jobs.map { |job| job["job_class"] }).not_to include("AddOns::InstallJob")
  end

  it "refuses to move a project or add-on onto another account's cluster" do
    project = create(:project, cluster: own_cluster, account:) # the factory otherwise moves the cluster to a new account
    patch project_path(project), params: { project: { cluster_id: other_cluster.id } }
    expect(project.reload.cluster).to eq(own_cluster)
    sibling = create(:cluster, account:) # moving within the account still works
    patch project_path(project), params: { project: { cluster_id: sibling.id } }
    expect(project.reload.cluster).to eq(sibling)

    add_on = create(:add_on, cluster: own_cluster)
    patch add_on_path(add_on), params: { add_on: { cluster_id: other_cluster.id, chart_url: add_on.chart_url, version: add_on.version, repository_url: add_on.repository_url } }
    expect(add_on.reload.cluster).to eq(own_cluster)
    expect(enqueued_jobs.map { |job| job["job_class"] }).not_to include("AddOns::InstallJob")
  end
end
