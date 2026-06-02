require 'rails_helper'

RSpec.describe Onboarding::Create do
  let(:params) do
    ActionController::Parameters.new(
      account: { name: 'testorg' },
      user: { email: 'admin@example.com', password: 'password123' },
      connect_cluster: "1",
    )
  end

  describe '.call' do
    context 'when not running in-cluster' do
      before do
        allow(K8::Connection).to receive(:in_cluster?).and_return(false)
      end

      it 'creates admin user and account without a cluster' do
        result = described_class.call(params)

        expect(result).to be_success
        expect(result.user).to be_persisted
        expect(result.user.email).to eq('admin@example.com')
        expect(result.user.admin).to be true
        expect(result.account.name).to eq('testorg')
        expect(result.account.owner).to eq(result.user)
        expect(AccountUser.find_by(account: result.account, user: result.user).role).to eq('owner')
        expect(Cluster.count).to eq(0)
      end
    end

    context 'when running in-cluster and connect_cluster is enabled' do
      before do
        allow(K8::Connection).to receive(:in_cluster?).and_return(true)
        allow(Clusters::SyncPackages).to receive(:execute).and_return(LightService::Context.make)
      end

      it 'creates admin user, account, and in-cluster cluster' do
        result = described_class.call(params)

        expect(result).to be_success
        expect(result.user).to be_persisted
        expect(result.account).to be_persisted
        expect(result[:cluster]).to be_persisted
        expect(result[:cluster].name).to eq('in-cluster')
        expect(result[:cluster].in_cluster?).to be true
        expect(result[:cluster].status).to eq('running')
        expect(result[:cluster].account).to eq(result.account)
      end
    end

    context 'when running in-cluster but connect_cluster is disabled' do
      let(:params) do
        ActionController::Parameters.new(
          account: { name: 'testorg' },
          user: { email: 'admin@example.com', password: 'password123' },
          connect_cluster: "0",
        )
      end

      before do
        allow(K8::Connection).to receive(:in_cluster?).and_return(true)
      end

      it 'creates admin user and account without a cluster' do
        result = described_class.call(params)

        expect(result).to be_success
        expect(result.user).to be_persisted
        expect(result.account).to be_persisted
        expect(Cluster.count).to eq(0)
      end
    end

    context 'when user email is invalid' do
      let(:params) do
        ActionController::Parameters.new(
          account: { name: 'testorg' },
          user: { email: '', password: 'password123' },
          connect_cluster: "1",
        )
      end

      it 'fails with an error' do
        result = described_class.call(params)
        expect(result).to be_failure
      end
    end
  end
end
