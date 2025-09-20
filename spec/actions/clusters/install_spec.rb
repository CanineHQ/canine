require 'rails_helper'

RSpec.describe Clusters::Install do
  let(:account) { create(:account) }
  let(:cluster) { create(:cluster, account: account, status: :initializing) }
  let(:user) { create(:user) }
  let(:connection) { instance_double(K8::Connection) }
  let(:kubectl) { instance_double(K8::Kubectl) }
  let(:cli_runner) { instance_double(Cli::RunAndLog) }

  before do
    allow(K8::Connection).to receive(:new).with(cluster, user).and_return(connection)
    allow(Cli::RunAndLog).to receive(:new).with(cluster).and_return(cli_runner)
    allow(K8::Kubectl).to receive(:new).with(connection, cli_runner).and_return(kubectl)
  end

  describe '.recipe' do
    context 'when account has no stack manager' do
      before do
        allow(account).to receive(:stack_manager).and_return(nil)
      end

      it 'returns the default recipe' do
        expect(described_class.recipe(cluster, user)).to eq(described_class::DEFAULT_RECIPE)
      end
    end

    context 'when account has a stack manager' do
      let(:stack_manager) { create(:stack_manager, account: account) }
      let(:portainer_stack) { Portainer::Stack.new(stack_manager) }
      let(:custom_recipe) { [ Clusters::IsReady, Clusters::CreateNamespace ] }

      before do
        allow(account).to receive(:stack_manager).and_return(stack_manager)
        allow(stack_manager).to receive(:stack).and_return(portainer_stack)
        allow(portainer_stack).to receive(:install_recipe).and_return(custom_recipe)
      end

      it 'returns the stack manager recipe' do
        expect(described_class.recipe(cluster, user)).to eq(custom_recipe)
      end
    end
  end

  describe '.run_install' do
    let(:recipe) { [ Clusters::IsReady ] }
    let(:params) { { cluster: cluster, user: user, kubectl: kubectl, connection: connection } }
    let(:successful_context) { LightService::Context.make(success: true) }
    let(:mock_context) { instance_double(LightService::Context) }

    it 'calls with and reduce with the correct parameters' do
      expect(described_class).to receive(:with).with(params).and_return(mock_context)
      expect(mock_context).to receive(:reduce).with(recipe).and_return(successful_context)

      result = described_class.run_install(recipe, params)

      expect(result).to eq(successful_context)
    end
  end

  describe '.call' do
    let(:successful_context) { LightService::Context.make(success: true) }
    let(:recipe) { described_class::DEFAULT_RECIPE }

    before do
      allow(described_class).to receive(:recipe).with(cluster, user).and_return(recipe)
      allow(described_class).to receive(:run_install).and_return(successful_context)
    end

    context 'when installation succeeds' do
      it 'sets cluster status to running' do
        expect(cluster).to receive(:running!)
        described_class.call(cluster, user)
      end

      it 'returns the successful context' do
        allow(cluster).to receive(:running!)
        result = described_class.call(cluster, user)
        expect(result).to be_success
      end

      it 'calls run_install with correct parameters' do
        expect(described_class).to receive(:run_install).with(
          recipe,
          hash_including(cluster: cluster, user: user, kubectl: kubectl, connection: connection)
        )
        allow(cluster).to receive(:running!)
        described_class.call(cluster, user)
      end
    end

    context 'when installation fails' do
      let(:failed_context) do
        context = LightService::Context.make
        context.fail!
        context
      end

      before do
        allow(described_class).to receive(:run_install).and_return(failed_context)
      end

      it 'sets cluster status to failed' do
        expect(cluster).to receive(:failed!)
        described_class.call(cluster, user)
      end

      it 'returns the failed context' do
        allow(cluster).to receive(:failed!)
        result = described_class.call(cluster, user)
        expect(result).to be_failure
      end
    end

    context 'when an exception is raised' do
      let(:error) { StandardError.new('Something went wrong') }

      before do
        allow(described_class).to receive(:run_install).and_raise(error)
      end

      it 'sets cluster status to failed' do
        expect(cluster).to receive(:failed!)
        expect { described_class.call(cluster, user) }.to raise_error(error)
      end

      it 're-raises the exception' do
        allow(cluster).to receive(:failed!)
        expect { described_class.call(cluster, user) }.to raise_error(error)
      end
    end
  end
end
