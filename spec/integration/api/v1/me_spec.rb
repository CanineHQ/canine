# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe Api::V1::MeController, :swagger, type: :request do
  let(:api_token) { create :api_token, user: }
  let(:'X-API-Key') { api_token.access_token }
  let(:account) { create :account }
  let(:user) { create :user }
  let!(:account_user) { create :account_user, account:, user: }

  path '/api/v1/me' do
    get('Show Current User') do
      tags 'Me'
      operationId 'showMe'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'

      response(200, 'successful') do
        schema type: :object,
               properties: {
                 id: { type: :integer },
                 email: { type: :string },
                 name: { type: :string },
                 created_at: { type: :string, format: 'date-time' },
                 current_account: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     name: { type: :string },
                     slug: { type: :string }
                   },
                   required: %w[id name slug]
                 },
                 accounts: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       name: { type: :string },
                       slug: { type: :string }
                     },
                     required: %w[id name slug]
                   }
                 }
               },
               required: %w[id email name created_at current_account accounts]
        run_test!
      end
    end
  end

  it "accepts an OAuth access token with an API scope instead of an API key, until it's revoked" do
    application = Doorkeeper::Application.create!(name: "Canine Connect", redirect_uri: "canine-connect://oauth/callback", confidential: false)
    token_with = ->(scopes) { Doorkeeper::AccessToken.create!(application:, resource_owner_id: user.id, scopes:) }
    request_as = ->(token, verb = :get, path = "/api/v1/me") {
      send(verb, path, headers: { "Authorization" => "Bearer #{token.token}", "Accept" => "application/json" })
      response.status
    }

    read = token_with.("read")
    expect(request_as.(read)).to eq(200)
    expect(JSON.parse(response.body)["email"]).to eq(user.email)
    # Read-only tokens cannot change anything
    expect(request_as.(read, :post, "/api/v1/projects/anything/deploy")).to eq(403)
    expect(request_as.(token_with.("public"), :post, "/api/v1/projects/anything/deploy")).to eq(404)

    # A sign-in token from an auth proxy says who the user is; it is not access to the API
    expect(request_as.(token_with.("openid profile email"))).to eq(403)

    orphan = Doorkeeper::AccessToken.create!(application:, resource_owner_id: nil, scopes: "public")
    expect(request_as.(orphan)).to eq(401)

    read.revoke
    expect(request_as.(read)).to eq(401)
  end
end
