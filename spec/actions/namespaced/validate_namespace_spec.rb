require 'rails_helper'

RSpec.describe Namespaced::ValidateNamespace do
  let(:cluster) { create(:cluster) }
  let(:user) { create(:user) }
  let(:k8_client) { instance_double(K8::Client) }

  before do
    allow(K8::Client).to receive(:new).and_return(k8_client)
  end

  describe '.execute' do
    context 'with unmanaged namespace' do
      let(:project) do
        build(:project, namespace: 'my-custom-namespace', managed_namespace: false)
      end

      context 'that doesnt exist' do
        before do
          allow(k8_client).to receive(
            :get_namespaces
          ).and_return([ OpenStruct.new(metadata: OpenStruct.new(name: "test-app")) ])
        end

        it 'fails' do
          expect(described_class.execute(namespaced: project, user:)).to be_failure
        end
      end

      context 'that does exist' do
        before do
          allow(k8_client).to receive(
            :get_namespaces,
          ).and_return([ OpenStruct.new(metadata: OpenStruct.new(name: "my-custom-namespace")) ])
        end

        it 'succeeds' do
          expect(described_class.execute(namespaced: project, user:)).to be_success
        end
      end
    end

    context 'with managed namespace' do
      let(:project) do
        build(
          :project,
          name: 'test-app',
          cluster: cluster,
          managed_namespace: true,
          namespace: 'test-app'
        )
      end
      context 'when namespace does not exist' do
        before do
          allow(k8_client).to receive(:get_namespaces).and_return([])
        end

        it 'succeeds' do
          expect(described_class.execute(namespaced: project, user: user)).to be_success
        end
      end

      context 'when namespace already exists' do
        before do
          allow(k8_client).to receive(:get_namespaces).and_return([ existing_namespace ])
        end

        context 'when namespace is not managed by Canine' do
          let(:existing_namespace) do
            OpenStruct.new(metadata: OpenStruct.new(name: 'test-app'))
          end

          it 'fails with error message' do
            result = described_class.execute(namespaced: project, user: user)
            expect(result).to be_failure
            expect(result.message).to include("already exists")
          end
        end

        context 'when namespace is managed by Canine' do
          let(:existing_namespace) do
            OpenStruct.new(metadata: OpenStruct.new(name: 'test-app', labels: OpenStruct.new(caninemanaged: "true")))
          end

          it 'succeeds' do
            result = described_class.execute(namespaced: project, user: user)
            expect(result).to be_success
          end
        end
      end
    end
  end
end
