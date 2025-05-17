require 'rails_helper'

RSpec.describe Async::K8::ClusterIpViewModel do
  let(:cluster) { create(:cluster) }
  let(:project) { create(:project, cluster: cluster) }
  let(:service) { create(:service, project: project) }
  let(:view_model) { described_class.new(cluster.account.owner, service_id: service.id) }

  describe '#async_render' do
    let(:ingress) { instance_double(K8::Stateless::Ingress) }

    before do
      allow(K8::Stateless::Ingress).to receive(:new).with(service).and_return(ingress)
    end

    context 'when ingress returns public IP' do
      before do
        allow(ingress).to receive(:ip_address).and_return('8.8.8.8')
      end

      it 'returns the IP in a pre tag' do
        expect(view_model.async_render).to include('8.8.8.8')
      end
    end

    context 'when ingress returns private IP' do
      before do
        allow(ingress).to receive(:ip_address).and_return('10.0.0.1')
        allow(Resolv).to receive(:getaddress).with('example.com').and_return('1.2.3.4')
      end

      it 'resolves and returns public IP' do
        expect(view_model.async_render).to include('1.2.3.4')
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
        expect(view_model.async_render).to include('1.2.3.4')
      end
    end
  end
end
