require 'rails_helper'
RSpec.shared_context 'with portainer' do
  before do
    headers = { 'Content-Type' => 'application/json' }
    WebMock.stub_request(:any, %r{/api/kubernetes/config}).to_return(
      status: 200, body: File.read(Rails.root.join(*%w[spec resources portainer kubeconfig.json])), headers:
    )
    WebMock.stub_request(:any, %r{/api/endpoints}).to_return(
      status: 200, body: File.read(Rails.root.join(*%w[spec resources portainer endpoints.json])), headers:
    )
    WebMock.stub_request(:any, %r{/api/auth/oauth/validate}).to_return(
      status: 200, body: File.read(Rails.root.join(*%w[spec resources portainer authenticate.json])), headers:
    )
    WebMock.stub_request(:any, %r{/api/auth}).to_return(
      status: 200, body: File.read(Rails.root.join(*%w[spec resources portainer authenticate.json])), headers:
    )
  end
end
