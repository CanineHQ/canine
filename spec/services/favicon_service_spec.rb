require 'rails_helper'

RSpec.describe FaviconService do
  describe '#fetch_url and #exists?' do
    it 'returns correct favicon URLs and checks existence' do
      service = FaviconService.new('https://www.github.com:8080/path')

      expect(service.fetch_url).to eq('https://icons.duckduckgo.com/ip3/github.com.ico')
      expect(service.fetch_url(size: 128, provider: :google)).to eq('https://www.google.com/s2/favicons?domain=github.com&sz=128')
      expect(service.fetch_url(provider: :duckduckgo)).to eq('https://icons.duckduckgo.com/ip3/github.com.ico')
      expect(service.fetch_url(provider: :direct)).to eq('https://github.com/favicon.ico')

      # Mock the exists? method to avoid actual HTTP requests in tests
      allow_any_instance_of(FaviconService).to receive(:check_favicon_exists).and_return(true)
      expect(service.exists?).to be true
    end

    it 'returns nil/false for invalid domains' do
      expect(FaviconService.new(nil).fetch_url).to be_nil
      expect(FaviconService.new('').fetch_url).to be_nil
      expect(FaviconService.new('   ').fetch_url).to be_nil
      expect(FaviconService.new(nil).exists?).to be false
    end
  end
end
