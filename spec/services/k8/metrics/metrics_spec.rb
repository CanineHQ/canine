require 'rails_helper'

RSpec.describe K8::Metrics::Metrics do
  describe '.call' do
    let(:cluster) { create(:cluster) }
    let(:user) { create(:user) }
    let(:connection) { K8::Connection.new(cluster, user) }
    let(:pod) do
      double('Pod', name: 'pod1', cpu: 1, memory: 512)
    end
    let(:node) do
      double(
        'Node',
        name: 'node1',
        cpu_cores: 2,
        total_cpu: 4,
        used_memory: 1024,
        total_memory: 2048,
        namespaces: [
          [
            'namespace1',
            [ pod ]
          ]
        ]
      )
    end

    before do
      allow(K8::Metrics::Api::Node).to receive(:ls).with(connection).and_return([ node ])
    end

    subject { K8::Metrics::Metrics.call(connection) }

    it 'creates metrics for nodes' do
      expect { subject }.to change { cluster.metrics.count }.by(4)
    end

    it 'creates metrics for pods' do
      subject

      expect(cluster.metrics.node_only_tags[0].metadata["cpu"]).to eq(2)
      expect(cluster.metrics.node_only_tags[0].metadata["total_cpu"]).to eq(4)
      expect(cluster.metrics.node_only_tags[1].metadata["memory"]).to eq(1024)
      expect(cluster.metrics.node_only_tags[1].metadata["total_memory"]).to eq(2048)
    end
  end
end
