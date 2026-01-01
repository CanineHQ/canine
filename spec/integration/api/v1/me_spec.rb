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
end
