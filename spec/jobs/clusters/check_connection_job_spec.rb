require 'rails_helper'

RSpec.describe Clusters::CheckConnectionJob do
  let(:cluster) { create(:cluster, status: :running) }
  let(:client) { instance_double(K8::Client) }

  before { allow(K8::Client).to receive(:new).and_return(client) }

  it 'records when a cluster stops being reachable and clears it when it comes back' do
    allow(client).to receive(:can_connect?).and_return(false)
    described_class.perform_now(cluster)
    expect(cluster.reload.unreachable_since).to be_within(1.minute).of(Time.current)
    expect { described_class.perform_now(cluster) }.not_to(change { cluster.reload.unreachable_since })

    allow(client).to receive(:can_connect?).and_return(true)
    described_class.perform_now(cluster)
    expect(cluster.reload.unreachable_since).to be_nil

    allow(client).to receive(:can_connect?).and_raise(StandardError, "boom")
    described_class.perform_now(cluster)
    expect(cluster.reload.unreachable_since).to be_present
  end
end
