require 'rails_helper'

RSpec.describe Clusters::Create do
  let(:kubeconfig_yaml) { File.read(Rails.root.join('spec/resources/k8/kubeconfig.yml')) }
  let(:supplied_kubeconfig) { YAML.safe_load(kubeconfig_yaml) }
  # ParseParams mutates what it is given, so every call gets a fresh copy.
  def params
    ActionController::Parameters.new(
      cluster: {
        name: "test-cluster",
        cluster_type: "k8s",
        kubeconfig_yaml_format: "true",
        kubeconfig: kubeconfig_yaml
      }
    )
  end
  let(:account_user) { create(:account_user) }
  let(:runner) { instance_double(Cli::RunAndReturnOutput) }

  before do
    allow(Clusters::ValidateKubeConfig).to receive(:can_connect?).and_return(true)
    allow(Cli::RunAndReturnOutput).to receive(:new).and_return(runner)
    allow_any_instance_of(K8::ManagerServiceAccount).to receive(:sleep)
  end

  def stub_kubectl(token:, full_access: "yes")
    allow(runner).to receive(:call) do |command, **|
      if command.include?("can-i") then full_access
      elsif command.include?("apply") then ""
      else Base64.strict_encode64(token)
      end
    end
  end

  it 'keeps the service account credentials and discards the supplied kubeconfig' do
    stub_kubectl(token: "manager-token")

    result = described_class.call(params, account_user)

    expect(result).to be_success
    cluster = result.cluster.reload
    source_context = supplied_kubeconfig["contexts"].find { |ctx| ctx["name"] == supplied_kubeconfig["current-context"] }
    source_cluster = supplied_kubeconfig["clusters"].find { |cl| cl["name"] == source_context["context"]["cluster"] }["cluster"]
    expect(cluster).to have_attributes(
      kubeconfig: nil,
      server_url: source_cluster["server"],
      certificate_authority_data: source_cluster["certificate-authority-data"],
      service_account_token: "manager-token"
    )
    expect(cluster).to be_manager_service_account
    expect(Cluster.connection.select_value("SELECT service_account_token FROM clusters WHERE id = #{cluster.id}")).not_to include("manager-token")
    expect(runner).to have_received(:call).with(array_including("kubectl", "apply"), anything)

    # Canine connects with the stored token; anything handed to a person gets one that expires.
    connection = K8::Connection.new(cluster, account_user.user)
    expect(cluster.service_account_name).to match(/\Acanine-manager-\h{8}\z/)
    expect(connection.kubeconfig["users"]).to eq([ { "name" => cluster.service_account_name, "user" => { "token" => "manager-token" } } ])
    expect(connection.kubeconfig["clusters"].first["cluster"]).to eq(source_cluster.slice("server", "certificate-authority-data"))
    allow(runner).to receive(:call).with(array_including("create", "token", "--duration=86400s"), anything).and_return("short-lived\n")
    temporary = connection.temporary_kubeconfig
    expect(temporary["users"].first["user"]).to eq("token" => "short-lived")
    expect(temporary["clusters"]).to eq(connection.kubeconfig["clusters"])
  end

  it 'does not save the cluster when the service account cannot be created' do
    allow(runner).to receive(:call).and_raise(Cli::CommandFailedError, "forbidden")
    result = described_class.call(params, account_user)
    expect(result).to be_failure
    expect(result.cluster).not_to be_persisted
    expect(result.cluster.errors[:kubeconfig].join).to include("forbidden")

    stub_kubectl(token: "")
    result = described_class.call(params, account_user)
    expect(result).to be_failure
    expect(result.cluster.errors[:kubeconfig].join).to include("did not issue a token")

    # A token the cluster issued but that cannot act through this address (a proxy): keep what was supplied.
    stub_kubectl(token: "manager-token", full_access: "no")
    allow(K8::ManagerServiceAccount).to receive(:sleep)
    result = described_class.call(params, account_user)
    expect(result).to be_failure
    expect(result.cluster).to have_attributes(persisted?: false, service_account_token: nil, kubeconfig: supplied_kubeconfig)
    expect(runner).to have_received(:call).with(array_including("delete", "clusterrolebinding"), anything)
  end
end
