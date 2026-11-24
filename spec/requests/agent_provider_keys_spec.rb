require "rails_helper"

RSpec.describe "Agent provider keys", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:account) { create(:account) }

  before do
    sign_in account.owner
    Flipper.enable(:agent_computers, account)
  end

  it "escapes the key's name in the saved and deleted notices" do
    name = %(<img src=x onerror="alert(1)">)
    post agent_provider_keys_path, params: { agent_provider_key: { provider: "openrouter", name:, api_key: "sk-or-v1-abcdef123456" } }
    follow_redirect!
    expect(response.body).to include("&lt;img src=x").and include("saved.")
    expect(response.body).not_to include("<img src=x")

    delete agent_provider_key_path(account.agent_provider_keys.last)
    follow_redirect!
    expect(response.body).to include("&lt;img src=x").and include("deleted.")
    expect(response.body).not_to include("<img src=x")
  end
end
