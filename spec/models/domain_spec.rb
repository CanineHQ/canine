require 'rails_helper'

RSpec.describe Domain, type: :model do
  let(:domain) { build(:domain) }

  describe '#downcase_domain_name' do
    it 'downcases the domain name before saving' do
      domain.domain_name = "EXAMPLE.COM"
      domain.save
      expect(domain.domain_name).to eq("example.com")
    end
  end

  describe '#strip_protocol' do
    it 'removes the protocol from the domain name' do
      domain.domain_name = "http://example.com"
      domain.send(:strip_protocol)
      expect(domain.domain_name).to eq("example.com")
    end
  end

  describe '#domain_name_has_tld' do
    it 'adds an error if the domain name does not have a TLD' do
      domain.domain_name = "example"
      domain.valid?
      expect(domain.errors[:domain_name]).to include("is not valid")
    end

    it 'does not add an error if the domain name has a TLD' do
      domain.domain_name = "example.com"
      domain.valid?
      expect(domain.errors[:domain_name]).to be_empty
    end
  end
end
