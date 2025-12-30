require 'rails_helper'
RSpec.shared_context 'with rancher' do
  before do
    headers = { 'Content-Type' => 'application/json' }

    WebMock.stub_request(:get, %r{/v3$}).to_return(
      status: 200, body: '{"type": "apiVersion", "apiVersion": {"version": "v3"}}', headers: headers
    )

    WebMock.stub_request(:get, %r{/v3/clusters$}).to_return(
      status: 200, body: File.read(Rails.root.join(*%w[spec resources rancher clusters.json])), headers: headers
    )

    WebMock.stub_request(:get, %r{/v3/clusters/}).to_return(
      status: 200, body: '{"id": "c-m-xxxxxxxx", "name": "local", "state": "active", "provider": "rke2", "version": {"gitVersion": "v1.28.4+rke2r1"}}', headers: headers
    )

    WebMock.stub_request(:post, %r{/v3/clusters/.+\?action=generateKubeconfig}).to_return(
      status: 200, body: File.read(Rails.root.join(*%w[spec resources rancher kubeconfig.json])), headers: headers
    )

    WebMock.stub_request(:get, %r{/v3/users}).to_return(
      status: 200, body: File.read(Rails.root.join(*%w[spec resources rancher user.json])), headers: headers
    )

    WebMock.stub_request(:get, %r{/v3/catalogs}).to_return(
      status: 200, body: File.read(Rails.root.join(*%w[spec resources rancher catalogs.json])), headers: headers
    )
  end
end
