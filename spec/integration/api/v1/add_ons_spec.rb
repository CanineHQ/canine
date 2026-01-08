# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe Api::V1::AddOnsController, :swagger, type: :request do
  include ApplicationHelper
  let(:user) { create :user }
  let(:account) { create :account }
  let!(:account_user) { create :account_user, user:, account:, role: :owner }
  let(:api_token) { create :api_token, user: }
  let(:'X-API-Key') { api_token.access_token }
  let(:cluster) { create :cluster, account: }
  let(:add_on) { create :add_on, cluster:, status: :installed }

  let(:helm_service) { instance_double(K8::Helm::Service) }

  before do
    allow(K8::Helm::Service).to receive(:create_from_add_on).and_return(helm_service)
    allow(helm_service).to receive(:restart)
  end

  path '/api/v1/add_ons' do
    get('List Add Ons') do
      tags 'Add Ons'
      operationId 'listAddOns'

      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/add_ons'

        before { add_on }

        run_test!
      end
    end
  end

  path '/api/v1/add_ons/{id}' do
    let(:id) { add_on.name }

    get('Show Add On') do
      tags 'Add Ons'
      operationId 'showAddOn'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :id, in: :path, type: :string, description: 'Add On name'

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/add_on'
        run_test!
      end

      response(404, 'not found') do
        let(:id) { 'nonexistent-addon' }
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'Resource not found' }
               }
        run_test!
      end
    end
  end

  path '/api/v1/add_ons/{id}/restart' do
    let(:id) { add_on.name }

    post('Restart Add On') do
      tags 'Add Ons'
      operationId 'restartAddOn'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'X-API-Key', in: :header, type: :string, description: 'API Key'
      parameter name: :id, in: :path, type: :string, description: 'Add On name'

      response(200, 'successful') do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Add on redis has been restarted' }
               },
               required: %w[message]
        run_test!
      end
    end
  end
end
