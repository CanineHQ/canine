require 'rails_helper'

RSpec.describe AddOns::UninstallHelmChart do
  let(:add_on) { create(:add_on) }
  let(:user) { create(:user) }
  let(:connection) { K8::Connection.new(add_on, user) }
  let(:kubectl) { instance_double(K8::Kubectl) }
  let(:helm_client) { instance_double(K8::Helm::Client) }
  let(:client) { instance_double(K8::Client) }

  before do
    allow(K8::Kubectl).to receive(:new).and_return(kubectl)
    allow(kubectl).to receive(:apply_yaml)
    allow(K8::Helm::Client).to receive(:connect).and_return(helm_client)
    allow(helm_client).to receive(:ls).and_return([])
    allow(K8::Client).to receive(:new).and_return(client)
    allow(client).to receive(:get_namespaces).and_return([])
  end

  describe '#execute' do
    context 'with an unmanaged namespace' do
      let(:add_on) { create(:add_on, managed_namespace: false) }
      it 'does not delete the namespace' do
        expect(client).not_to receive(:delete_namespace)
        described_class.execute(connection:)
      end
    end

    context 'with a managed namespace' do
      it 'deletes the namespace' do
        allow(client).to receive(:get_namespaces).and_return([ OpenStruct.new(metadata: OpenStruct.new(name: add_on.namespace)) ])
        expect(client).to receive(:delete_namespace)

        described_class.execute(connection:)
      end
    end

    it 'uninstalls the helm chart successfully' do
      expect(add_on).to receive(:uninstalled!)
      expect(add_on).to receive(:destroy!)

      described_class.execute(connection:)
    end
  end
end
