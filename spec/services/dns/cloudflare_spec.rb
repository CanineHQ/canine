require 'rails_helper'

RSpec.describe Dns::Cloudflare do
  let(:api_token) { 'test_token' }
  let(:zone_id) { 'zone123' }
  let(:domain) { 'oncanine.run' }
  let(:client) { described_class.new(api_token: api_token, zone_id: zone_id, domain: domain) }
  let(:base_url) { "https://api.cloudflare.com/client/v4" }

  def fixture(name)
    File.read(Rails.root.join("spec/resources/cloudflare/#{name}.json"))
  end

  describe '#create_a_record' do
    let(:subdomain) { 'test' }
    let(:ip_address) { '192.168.1.1' }

    context 'when record does not exist' do
      before do
        stub_request(:get, "#{base_url}/zones/#{zone_id}/dns_records")
          .with(query: { name: "#{subdomain}.#{domain}", type: "A" })
          .to_return(status: 200, body: fixture('list_records_empty'))

        stub_request(:post, "#{base_url}/zones/#{zone_id}/dns_records")
          .to_return(status: 200, body: fixture('create_record'))
      end

      it 'creates a new A record' do
        result = client.create_a_record(subdomain: subdomain, ip_address: ip_address)
        expect(result['id']).to eq('new123')
        expect(result['type']).to eq('A')
      end
    end

    context 'when record already exists' do
      before do
        stub_request(:get, "#{base_url}/zones/#{zone_id}/dns_records")
          .with(query: { name: "#{subdomain}.#{domain}", type: "A" })
          .to_return(status: 200, body: fixture('list_records'))

        stub_request(:patch, "#{base_url}/zones/#{zone_id}/dns_records/abc123")
          .to_return(status: 200, body: fixture('update_record'))
      end

      it 'updates the existing record' do
        result = client.create_a_record(subdomain: subdomain, ip_address: '192.168.1.2')
        expect(result['id']).to eq('abc123')
        expect(result['content']).to eq('192.168.1.2')
      end
    end
  end

  describe '#create_cname_record' do
    let(:subdomain) { 'www' }
    let(:target) { 'example.com' }

    context 'when record does not exist' do
      before do
        stub_request(:get, "#{base_url}/zones/#{zone_id}/dns_records")
          .with(query: { name: "#{subdomain}.#{domain}", type: "CNAME" })
          .to_return(status: 200, body: fixture('list_records_empty'))

        stub_request(:post, "#{base_url}/zones/#{zone_id}/dns_records")
          .to_return(status: 200, body: fixture('create_record'))
      end

      it 'creates a new CNAME record' do
        result = client.create_cname_record(subdomain: subdomain, target: target)
        expect(result['id']).to eq('new123')
      end
    end
  end

  describe '#delete_record' do
    let(:subdomain) { 'test' }

    context 'when record exists' do
      before do
        stub_request(:get, "#{base_url}/zones/#{zone_id}/dns_records")
          .with(query: { name: "#{subdomain}.#{domain}" })
          .to_return(status: 200, body: fixture('list_records'))

        stub_request(:delete, "#{base_url}/zones/#{zone_id}/dns_records/abc123")
          .to_return(status: 200, body: fixture('delete_record'))
      end

      it 'deletes the record and returns true' do
        expect(client.delete_record(subdomain: subdomain)).to be true
      end
    end

    context 'when record does not exist' do
      before do
        stub_request(:get, "#{base_url}/zones/#{zone_id}/dns_records")
          .with(query: { name: "#{subdomain}.#{domain}" })
          .to_return(status: 200, body: fixture('list_records_empty'))
      end

      it 'returns false' do
        expect(client.delete_record(subdomain: subdomain)).to be false
      end
    end
  end

  describe '#record_exists?' do
    let(:subdomain) { 'test' }

    it 'returns true when record exists' do
      stub_request(:get, "#{base_url}/zones/#{zone_id}/dns_records")
        .with(query: { name: "#{subdomain}.#{domain}" })
        .to_return(status: 200, body: fixture('list_records'))

      expect(client.record_exists?(subdomain: subdomain)).to be true
    end

    it 'returns false when record does not exist' do
      stub_request(:get, "#{base_url}/zones/#{zone_id}/dns_records")
        .with(query: { name: "#{subdomain}.#{domain}" })
        .to_return(status: 200, body: fixture('list_records_empty'))

      expect(client.record_exists?(subdomain: subdomain)).to be false
    end
  end

  describe '#list_records' do
    it 'returns all records' do
      stub_request(:get, "#{base_url}/zones/#{zone_id}/dns_records")
        .to_return(status: 200, body: fixture('list_records'))

      records = client.list_records
      expect(records.length).to eq(1)
      expect(records.first['name']).to eq('test.oncanine.run')
    end

    it 'filters by type' do
      stub_request(:get, "#{base_url}/zones/#{zone_id}/dns_records")
        .with(query: { type: "A" })
        .to_return(status: 200, body: fixture('list_records'))

      records = client.list_records(type: "A")
      expect(records.first['type']).to eq('A')
    end
  end

  describe '#verify_connection' do
    it 'returns true when token is valid' do
      stub_request(:get, "#{base_url}/user/tokens/verify")
        .to_return(status: 200, body: fixture('verify_token'))

      expect(client.verify_connection).to be true
    end

    it 'returns false when token is invalid' do
      stub_request(:get, "#{base_url}/user/tokens/verify")
        .to_return(status: 401, body: fixture('error'))

      expect(client.verify_connection).to be false
    end
  end

  describe 'error handling' do
    it 'raises Dns::Client::Error on API failure' do
      stub_request(:get, "#{base_url}/zones/#{zone_id}/dns_records")
        .to_return(status: 401, body: fixture('error'))

      expect { client.list_records }.to raise_error(Dns::Client::Error, "Invalid access token")
    end
  end
end
