require 'rails_helper'

RSpec.describe FaviconService do
  describe '#fetch_url' do
    it 'returns correct favicon URLs for different providers' do
      service = FaviconService.new('https://www.github.com:8080/path')

      expect(service.fetch_url).to eq('https://www.google.com/s2/favicons?domain=github.com&sz=64')
      expect(service.fetch_url(size: 128, provider: :google)).to eq('https://www.google.com/s2/favicons?domain=github.com&sz=128')
      expect(service.fetch_url(provider: :duckduckgo)).to eq('https://icons.duckduckgo.com/ip3/github.com.ico')
      expect(service.fetch_url(provider: :direct)).to eq('https://github.com/favicon.ico')
    end

    it 'returns nil for invalid domains' do
      expect(FaviconService.new(nil).fetch_url).to be_nil
      expect(FaviconService.new('').fetch_url).to be_nil
      expect(FaviconService.new('   ').fetch_url).to be_nil
    end
  end
end
