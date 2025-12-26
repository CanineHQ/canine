# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SAML::Authenticator do
  let(:saml_config) { build(:saml_configuration) }
  let(:account) { build(:account) }
  let(:logger) { instance_double(Logger, info: nil, warn: nil, error: nil) }
  let(:authenticator) { described_class.new(saml_config, account: account, logger: logger) }

  let(:settings) { instance_double(OneLogin::RubySaml::Settings) }
  let(:saml_response) { instance_double(OneLogin::RubySaml::Response) }
  let(:attributes) do
    {
      'email' => [ 'john@example.com' ],
      'name' => [ 'John Doe' ]
    }
  end

  before do
    allow(saml_config).to receive(:settings_for).and_return(settings)
    allow(OneLogin::RubySaml::Response).to receive(:new).and_return(saml_response)
  end

  describe '#authenticate' do
    context 'when response is valid' do
      before do
        allow(saml_response).to receive(:is_valid?).and_return(true)
        allow(saml_response).to receive(:attributes).and_return(attributes)
        allow(saml_response).to receive(:nameid).and_return('john@example.com')
      end

      it 'returns success with user attributes' do
        result = authenticator.authenticate(saml_response: '<saml>response</saml>')

        expect(result.success?).to be true
        expect(result.email).to eq('john@example.com')
        expect(result.name).to eq('John Doe')
      end
    end

    context 'when response is invalid' do
      before do
        allow(saml_response).to receive(:is_valid?).and_return(false)
        allow(saml_response).to receive(:errors).and_return([ 'Signature validation failed' ])
      end

      it 'returns failure with error' do
        result = authenticator.authenticate(saml_response: '<saml>bad</saml>')

        expect(result.success?).to be false
        expect(result.error_message).to eq('Signature validation failed')
      end
    end

    context 'when email is missing' do
      before do
        allow(saml_response).to receive(:is_valid?).and_return(true)
        allow(saml_response).to receive(:attributes).and_return({})
        allow(saml_response).to receive(:nameid).and_return(nil)
      end

      it 'returns failure' do
        result = authenticator.authenticate(saml_response: '<saml>response</saml>')

        expect(result.success?).to be false
        expect(result.error_message).to eq('Email not found in SAML response')
      end
    end

    context 'when an error occurs' do
      before do
        allow(OneLogin::RubySaml::Response).to receive(:new).and_raise(StandardError.new('Parse error'))
      end

      it 'returns failure with error message' do
        result = authenticator.authenticate(saml_response: 'invalid')

        expect(result.success?).to be false
        expect(result.error_message).to eq('Parse error')
      end
    end
  end

  describe '#authorization_url' do
    let(:auth_request) { instance_double(OneLogin::RubySaml::Authrequest) }

    before do
      allow(OneLogin::RubySaml::Authrequest).to receive(:new).and_return(auth_request)
      allow(auth_request).to receive(:create).and_return('https://idp.example.com/sso?SAMLRequest=...')
    end

    it 'generates authorization URL' do
      url = authenticator.authorization_url(relay_state: '/dashboard')

      expect(auth_request).to have_received(:create).with(settings, RelayState: '/dashboard')
      expect(url).to include('https://idp.example.com/sso')
    end
  end

  describe '#metadata' do
    let(:meta) { instance_double(OneLogin::RubySaml::Metadata) }

    before do
      allow(OneLogin::RubySaml::Metadata).to receive(:new).and_return(meta)
      allow(meta).to receive(:generate).and_return('<EntityDescriptor>...</EntityDescriptor>')
    end

    it 'generates SP metadata' do
      result = authenticator.metadata

      expect(meta).to have_received(:generate).with(settings, true)
      expect(result).to include('EntityDescriptor')
    end
  end
end
