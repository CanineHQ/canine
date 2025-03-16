require 'rails_helper'

RSpec.describe Providers::GenerateConfigJson do
  let(:provider) { build(:provider, :docker_hub) }

  subject(:context) { described_class.execute(provider: provider) }

  describe '.execute' do
    it 'succeeds' do
      expect(context).to be_success
    end

    it 'generates a valid docker config json' do
      # First level base64 decode
      result = Base64.strict_decode64(context.docker_config_json)
      JSON.parse(result)
      auth = JSON.parse(result)['auths']['https://index.docker.io/v1/']['auth']
      username, password = Base64.strict_decode64(auth).split(':')
      expect(username).to eq(provider.username)
      expect(password).to eq(provider.access_token)
    end
  end
end
