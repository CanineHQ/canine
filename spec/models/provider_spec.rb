# == Schema Information
#
# Table name: providers
#
#  id                  :bigint           not null, primary key
#  access_token        :string
#  access_token_secret :string
#  auth                :text
#  expires_at          :datetime
#  last_used_at        :datetime
#  provider            :string
#  refresh_token       :string
#  registry_url        :string
#  uid                 :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  external_id         :string
#  sso_provider_id     :bigint
#  user_id             :bigint           not null
#
# Indexes
#
#  index_providers_on_sso_provider_id          (sso_provider_id)
#  index_providers_on_sso_provider_id_and_uid  (sso_provider_id,uid) UNIQUE WHERE (sso_provider_id IS NOT NULL)
#  index_providers_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (sso_provider_id => sso_providers.id)
#  fk_rails_...  (user_id => users.id)
#
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
