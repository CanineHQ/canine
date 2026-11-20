require 'rails_helper'

RSpec.describe "Cluster registrations", type: :request do
  let(:account_user) { create(:account_user) }
  let(:cluster) do
    params = ActionController::Parameters.new(cluster: { name: "eks-prod" })
    Clusters::CreateForRegistration.call(params, account_user).cluster
  end

  it 'connects a cluster from the registration command and then retires the link' do
    expect(cluster).to be_persisted.and be_registration_pending
    token = cluster.generate_token_for(:registration)
    path = cluster_registration_path(token)

    get path
    expect(response.body).to include("kubectl apply", "kind: ClusterRoleBinding", "#{cluster.service_account_name}-token", cluster_registration_url(token))
    expect(cluster.service_account_name).to match(/\Acanine-manager-\h{8}\z/)

    credentials = { server_url: "https://eks.example.com", certificate_authority_data: "Y2E=", service_account_token: Base64.strict_encode64("sa-token") }
    allow(Clusters::ValidateKubeConfig).to receive(:can_connect?).and_return(false)
    post path, params: credentials
    expect(response).to have_http_status(:unprocessable_entity)
    expect(cluster.reload).to be_registration_pending

    allow(Clusters::ValidateKubeConfig).to receive(:can_connect?).and_return(true)
    allow(K8::ManagerServiceAccount).to receive(:full_access?).and_return(false)
    post path, params: credentials
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("cluster-admin")

    allow(K8::ManagerServiceAccount).to receive(:full_access?).and_return(true)
    expect { post path, params: credentials }.to have_enqueued_job(Clusters::InstallJob).with(cluster, account_user.account.owner)
    expect(response).to have_http_status(:ok)
    expect(cluster.reload).to have_attributes(
      server_url: "https://eks.example.com", certificate_authority_data: "Y2E=", service_account_token: "sa-token", registration_pending?: false
    )

    get path
    expect(response).to have_http_status(:not_found)
    get "/cluster_registrations/not-a-token"
    expect(response).to have_http_status(:not_found)
  end
end
