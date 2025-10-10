# == Schema Information
#
# Table name: stack_managers
#
#  id                               :bigint           not null, primary key
#  access_token                     :string
#  enable_role_based_access_control :boolean          default(TRUE)
#  provider_url                     :string           not null
#  stack_manager_type               :integer          default("portainer"), not null
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  account_id                       :bigint           not null
#
# Indexes
#
#  index_stack_managers_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
require 'rails_helper'

RSpec.describe StackManager, type: :model do
  let(:account) { create(:account) }

  describe 'provider_url normalization' do
    it 'removes trailing slash from provider_url' do
      stack_manager = StackManager.create(
        account: account,
        provider_url: 'https://portainer.example.com/',
        stack_manager_type: :portainer
      )

      expect(stack_manager.provider_url).to eq('https://portainer.example.com')
    end

    it 'does not modify provider_url without trailing slash' do
      stack_manager = StackManager.create(
        account: account,
        provider_url: 'https://portainer.example.com',
        stack_manager_type: :portainer
      )

      expect(stack_manager.provider_url).to eq('https://portainer.example.com')
    end

    it 'removes path from provider_url' do
      stack_manager = StackManager.create(
        account: account,
        provider_url: 'https://portainer.example.com/api/',
        stack_manager_type: :portainer
      )

      expect(stack_manager.provider_url).to eq('https://portainer.example.com')
    end

    it 'preserves port number when removing path' do
      stack_manager = StackManager.create(
        account: account,
        provider_url: 'https://portainer.example.com:9443/',
        stack_manager_type: :portainer
      )

      expect(stack_manager.provider_url).to eq('https://portainer.example.com:9443')
    end

    it 'preserves port number without path' do
      stack_manager = StackManager.create(
        account: account,
        provider_url: 'https://portainer.example.com:9443',
        stack_manager_type: :portainer
      )

      expect(stack_manager.provider_url).to eq('https://portainer.example.com:9443')
    end

    it 'removes query parameters from provider_url' do
      stack_manager = StackManager.create(
        account: account,
        provider_url: 'https://portainer.example.com/?key=value',
        stack_manager_type: :portainer
      )

      expect(stack_manager.provider_url).to eq('https://portainer.example.com')
    end

    it 'removes path and fragment from provider_url' do
      stack_manager = StackManager.create(
        account: account,
        provider_url: 'https://portainer.portainer.svc.cluster.local:9443/#!/home',
        stack_manager_type: :portainer
      )

      expect(stack_manager.provider_url).to eq('https://portainer.portainer.svc.cluster.local:9443')
    end

    it 'leaves invalid URLs unchanged' do
      invalid_url = 'not a valid url/'
      stack_manager = StackManager.new(
        account: account,
        provider_url: invalid_url,
        stack_manager_type: :portainer
      )

      stack_manager.valid?
      expect(stack_manager.provider_url).to eq(invalid_url)
    end
  end

  describe '#domain_host' do
    it 'returns the host' do
      stack_manager = build(:stack_manager, provider_url: 'https://portainer.example.com:9443')
      expect(stack_manager.domain_host).to eq('portainer.example.com')
    end
  end

  describe '#is_user?' do
    let(:stack_manager) { build(:stack_manager, provider_url: 'https://portainer.example.com') }

    it 'returns true when user email ends with domain host' do
      user = double('User', email: 'john@portainer.example.com')
      expect(stack_manager.is_user?(user)).to be true
    end

    it 'returns false when user email does not end with domain host' do
      user = double('User', email: 'john@otherdomain.com')
      expect(stack_manager.is_user?(user)).to be false
    end
  end
end
