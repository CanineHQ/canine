require 'rails_helper'

RSpec.describe Networks::CheckDns do
  let(:cluster) { create(:cluster, cluster_type: :k3s) }
  let(:user) { create(:user) }
  let(:project) { create(:project, cluster: cluster) }
  let(:service) { create(:service, project: project) }
  let(:connection) { K8::Connection.new(cluster, user) }
  let(:http_route) { K8::Stateless::HttpRoute.new(service).connect(connection) }

  describe 'Dns::Utils.infer_expected_hostname' do
    context 'when http_route returns public IP' do
      before do
        allow(http_route).to receive(:hostname).and_return({ value: '8.8.8.8', type: :ip_address })
      end

      it 'returns the IP' do
        expect(Dns::Utils.infer_expected_hostname(http_route, connection)).to eq({ value: "8.8.8.8", type: :ip_address })
      end
    end

    context 'when http_route returns private IP' do
      before do
        allow(http_route).to receive(:hostname).and_return({ value: '10.0.0.1', type: :ip_address })
        allow(Resolv).to receive(:getaddress).with('example.com').and_return('1.2.3.4')
      end

      context 'when cluster is a single node cluster' do
        it 'resolves and returns public IP' do
          expect(Dns::Utils.infer_expected_hostname(http_route, connection)).to eq({ value: "1.2.3.4", type: :ip_address })
        end
      end
      context 'when cluster is not a single node cluster' do
        let(:cluster) { create(:cluster, cluster_type: :k8s) }
        it 'raises an error' do
          expect { Dns::Utils.infer_expected_hostname(http_route, connection) }.to raise_error("Private IP address detected for cluster type: k8s")
        end
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
        allow(http_route).to receive(:hostname).and_return({ value: '1.2.3.4', type: :ip_address })
      end

      it 'returns the hostname IP' do
        expect(Dns::Utils.infer_expected_hostname(http_route, connection)).to(eq({ value: "1.2.3.4", type: :ip_address }))
      end
    end
  end
end
