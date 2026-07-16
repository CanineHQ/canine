require 'rails_helper'

RSpec.describe FetchClusterMetricsJob do
  let(:cluster) { create(:cluster, status: :running) }

  describe '#perform' do
    it 'fetches metrics for the cluster' do
      allow(K8::Connection).to receive(:new).and_return(double("connection"))
      allow(K8::Metrics::Metrics).to receive(:call)

      described_class.new.perform(cluster)

      expect(K8::Metrics::Metrics).to have_received(:call)
    end

    it 'logs error and does not raise when metrics call fails' do
      allow(K8::Connection).to receive(:new).and_return(double("connection"))
      allow(K8::Metrics::Metrics).to receive(:call).and_raise(StandardError.new("connection refused"))

      expect { described_class.new.perform(cluster) }.not_to raise_error
    end

    it 'handles timeout without raising' do
      allow(K8::Connection).to receive(:new).and_return(double("connection"))
      allow(K8::Metrics::Metrics).to receive(:call).and_raise(Timeout::Error.new("execution expired"))

      expect { described_class.new.perform(cluster) }.not_to raise_error
    end
  end
end
