require 'rails_helper'

RSpec.describe Scheduled::SweepDnsRecordsJob do
  let(:zone_id) { 'zone123' }
  let(:domain) { 'oncanine.run' }
  let(:base_url) { "https://api.cloudflare.com/client/v4" }

  def cloudflare_response(result, total_pages: 1)
    {
      success: true,
      errors: [],
      messages: [],
      result: result,
      result_info: { page: 1, per_page: 100, total_pages: total_pages, count: result.size, total_count: result.size }
    }.to_json
  end

  describe '#perform' do
    context 'when dns is disabled' do
      before { allow(Dns::AutoSetupService).to receive(:enabled?).and_return(false) }

      it 'does nothing' do
        expect_any_instance_of(Dns::Cloudflare).not_to receive(:list_all_records)
        described_class.new.perform
      end
    end

    context 'when dns is enabled' do
      let(:project) { create(:project) }
      let(:service) { create(:service, project: project) }

      before do
        allow(Dns::AutoSetupService).to receive(:enabled?).and_return(true)
        stub_const("Dns::Cloudflare::API_TOKEN", "test_token")
        stub_const("Dns::Cloudflare::ZONE_ID", zone_id)
        stub_const("Dns::Cloudflare::DOMAIN", domain)
      end

      it 'deletes stale records matching auto-managed pattern but not in database' do
        create(:domain, service: service, domain_name: 'web-myapp.oncanine.run', auto_managed: true)

        all_records = [
          { "id" => "abc123", "type" => "A", "name" => "web-myapp.oncanine.run" },
          { "id" => "def456", "type" => "A", "name" => "stale-deleted.oncanine.run" },
          { "id" => "ghi789", "type" => "A", "name" => "www.oncanine.run" },
          { "id" => "jkl012", "type" => "TXT", "name" => "old-txt.oncanine.run" }
        ]

        stub_request(:get, "#{base_url}/zones/#{zone_id}/dns_records")
          .with(query: { per_page: 100, page: 1 })
          .to_return(status: 200, body: cloudflare_response(all_records))

        stub_request(:get, "#{base_url}/zones/#{zone_id}/dns_records")
          .with(query: { name: "stale-deleted.oncanine.run" })
          .to_return(status: 200, body: cloudflare_response([ all_records[1] ]))

        stub_request(:delete, "#{base_url}/zones/#{zone_id}/dns_records/def456")
          .to_return(status: 200, body: cloudflare_response({ id: "def456" }))

        described_class.new.perform

        # stale-deleted matches pattern and not in DB - deleted
        expect(WebMock).to have_requested(:delete, "#{base_url}/zones/#{zone_id}/dns_records/def456")
        # web-myapp is in DB - not deleted
        expect(WebMock).not_to have_requested(:delete, "#{base_url}/zones/#{zone_id}/dns_records/abc123")
        # www doesn't match pattern - not deleted
        expect(WebMock).not_to have_requested(:delete, "#{base_url}/zones/#{zone_id}/dns_records/ghi789")
        # TXT record - not deleted
        expect(WebMock).not_to have_requested(:delete, "#{base_url}/zones/#{zone_id}/dns_records/jkl012")
      end
    end
  end
end
