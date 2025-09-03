require 'rails_helper'

RSpec.describe Projects::ValidateNamespaceAvailability do
  let(:cluster) { create(:cluster) }
  let(:project) { build(:project, name: 'test-app', cluster: cluster) }
  let(:user) { create(:user) }
  let(:k8_client) { instance_double(K8::Client) }

  before do
    allow(K8::Client).to receive(:new).and_return(k8_client)
  end

  describe '.execute' do
    context 'when namespace does not exist' do
      before do
        allow(k8_client).to receive(:get_namespaces).and_return([])
      end

      it 'succeeds' do
        expect(described_class.execute(project: project, user: user)).to be_success
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
          result = described_class.execute(project: project, user: user)
          expect(result).to be_failure
          expect(result.message).to include("already exists")
        end
      end

      context 'when namespace is managed by Canine' do
        let(:existing_namespace) do
          OpenStruct.new(metadata: OpenStruct.new(name: 'test-app', labels: OpenStruct.new(caninemanaged: "true")))
        end

        it 'succeeds' do
          result = described_class.execute(project: project, user: user)
          expect(result).to be_success
        end
      end
    end
  end
end
