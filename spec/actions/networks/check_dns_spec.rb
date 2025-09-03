require 'rails_helper'

RSpec.describe Networks::CheckDns do
  let(:cluster) { create(:cluster) }
  let(:user) { create(:user) }
  let(:project) { create(:project, cluster: cluster) }
  let(:service) { create(:service, project: project) }
  let(:connection) { K8::Connection.new(cluster, user) }
  let(:ingress) { K8::Stateless::Ingress.new(service).connect(connection) }

  describe '.infer_expected_ip' do
    context 'when ingress returns public IP' do
      before do
        allow(ingress).to receive(:ip_address).and_return('8.8.8.8')
      end

      it 'returns the IP' do
        expect(described_class.infer_expected_ip(ingress, connection)).to eq('8.8.8.8')
      end
    end

    context 'when ingress returns private IP' do
      before do
        allow(ingress).to receive(:ip_address).and_return('10.0.0.1')
        allow(Resolv).to receive(:getaddress).with('example.com').and_return('1.2.3.4')
      end

      it 'resolves and returns public IP' do
        expect(described_class.infer_expected_ip(ingress, connection)).to eq('1.2.3.4')
      end
    end

    context 'when server hostname is an IP' do
      let(:cluster) do
        create(
          :cluster,
          kubeconfig: {
            "apiVersion" => "v1",
            "clusters" => [ { "name" => "test-cluster", "cluster" => { "server" => "https://1.2.3.4" } } ],
            "contexts" => [ { "name" => "test-cluster", "context" => { "cluster" => "test-cluster", "user" => "test-user" } } ],
            "current-context" => "test-cluster",
            "users" => [ { "name" => "test-user", "user" => { "token" => "test-token" } } ]
          }.to_json
        )
      end

      before do
        allow(ingress).to receive(:ip_address).and_return('10.0.0.1')
      end

      it 'returns the hostname IP' do
        expect(described_class.infer_expected_ip(ingress, connection)).to eq('1.2.3.4')
      end
    end
  end
end
