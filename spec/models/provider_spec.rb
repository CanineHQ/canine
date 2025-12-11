require 'rails_helper'

RSpec.describe Provider, type: :model do
  describe '#enterprise?' do
    it 'returns true for github with registry_url' do
      provider = build(:provider, :github, registry_url: 'https://github.example.com')
      expect(provider.enterprise?).to be true
    end

    it 'returns true for gitlab with registry_url' do
      provider = build(:provider, :gitlab, registry_url: 'https://gitlab.example.com')
      expect(provider.enterprise?).to be true
    end

    it 'returns false for github without registry_url' do
      provider = build(:provider, :github, registry_url: nil)
      expect(provider.enterprise?).to be false
    end

    it 'returns false for gitlab without registry_url' do
      provider = build(:provider, :gitlab, registry_url: nil)
      expect(provider.enterprise?).to be false
    end

    it 'returns false for container_registry even with registry_url' do
      provider = build(:provider, :container_registry)
      expect(provider.enterprise?).to be false
    end
  end

  describe '#api_base_url' do
    it 'returns registry_url without trailing slash when present' do
      provider = build(:provider, :github, registry_url: 'https://github.example.com/')
      expect(provider.api_base_url).to eq('https://github.example.com')
    end

    it 'returns github api base when github without registry_url' do
      provider = build(:provider, :github, registry_url: nil)
      expect(provider.api_base_url).to eq('https://api.github.com')
    end

    it 'returns gitlab api base when gitlab without registry_url' do
      provider = build(:provider, :gitlab, registry_url: nil)
      expect(provider.api_base_url).to eq('https://gitlab.com')
    end
  end
end
