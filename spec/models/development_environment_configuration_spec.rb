# == Schema Information
#
# Table name: development_environment_configurations
#
#  id                :bigint           not null, primary key
#  anthropic_api_key :string
#  application_path  :string           not null
#  branch_name       :string           not null
#  dockerfile_path   :string           not null
#  enabled           :boolean          default(TRUE)
#  ssh_password      :string
#  ssh_port          :integer          default(2222)
#  ssh_username      :string           default("developer")
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  project_id        :bigint           not null
#
# Indexes
#
#  index_development_environment_configurations_on_project_id  (project_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
require 'rails_helper'

RSpec.describe DevelopmentEnvironmentConfiguration, type: :model do
  let(:account) { create(:account) }
  let(:cluster) { create(:cluster, account: account) }
  let(:project) { create(:project, cluster: cluster) }
  let(:account_with_api_key) do
    acc = create(:account)
    acc.update!(anthropic_api_key: 'sk-account-key')
    acc
  end
  let(:cluster_with_api_key) { create(:cluster, account: account_with_api_key) }
  let(:project_with_account_key) { create(:project, cluster: cluster_with_api_key) }

  describe 'associations' do
    it { should belong_to(:project) }
  end

  describe 'validations' do
    subject { build(:development_environment_configuration, project: project) }

    it { should validate_presence_of(:dockerfile_path) }
    it { should validate_presence_of(:application_path) }
    it { should validate_presence_of(:branch_name) }
    it { should validate_uniqueness_of(:project_id) }

    it 'is valid with project level API key' do
      config = build(:development_environment_configuration,
                    project: project,
                    anthropic_api_key: 'sk-test-key')
      expect(config).to be_valid
    end

    it 'is valid without API key (can be added later)' do
      config = build(:development_environment_configuration,
                    project: project,
                    anthropic_api_key: nil)
      expect(config).to be_valid
    end
  end

  describe 'callbacks' do
    it 'generates SSH password before creation' do
      config = build(:development_environment_configuration,
                    project: project,
                    anthropic_api_key: 'sk-test',
                    ssh_password: nil)
      config.save!
      expect(config.ssh_password).to be_present
      expect(config.ssh_password.length).to eq(32) # hex(16) = 32 chars
    end

    it 'does not override existing SSH password' do
      existing_password = 'my-custom-password'
      config = build(:development_environment_configuration,
                    project: project,
                    anthropic_api_key: 'sk-test',
                    ssh_password: existing_password)
      config.save!
      expect(config.ssh_password).to eq(existing_password)
    end
  end

  describe '#effective_anthropic_api_key' do
    it 'returns project-level key when set' do
      config = create(:development_environment_configuration,
                     project: project,
                     anthropic_api_key: 'sk-project-key')
      expect(config.effective_anthropic_api_key).to eq('sk-project-key')
    end

    it 'returns account-level key when project key is nil' do
      # Test the method directly with mocked association
      config = build(:development_environment_configuration,
                    project: project,
                    anthropic_api_key: nil)

      # Mock the account to return an API key
      allow(config.project.cluster).to receive_message_chain(:account, :anthropic_api_key).and_return('sk-account-key')

      expect(config.effective_anthropic_api_key).to eq('sk-account-key')
    end

    it 'prefers project key over account key' do
      config = build(:development_environment_configuration,
                    project: project,
                    anthropic_api_key: 'sk-project-key')

      # Mock account to have a key too
      allow(config.project.cluster).to receive_message_chain(:account, :anthropic_api_key).and_return('sk-account-key')

      # Should still prefer project key
      expect(config.effective_anthropic_api_key).to eq('sk-project-key')
    end
  end

  describe '#api_key_configured?' do
    it 'returns true when project key is set' do
      config = create(:development_environment_configuration,
                     project: project,
                     anthropic_api_key: 'sk-test')
      expect(config.api_key_configured?).to be true
    end

    it 'returns true when account key is set' do
      config = build(:development_environment_configuration,
                    project: project,
                    anthropic_api_key: nil)

      # Mock the account to return an API key
      allow(config.project.cluster).to receive_message_chain(:account, :anthropic_api_key).and_return('sk-account-key')

      expect(config.api_key_configured?).to be true
    end

    it 'returns false when neither key is set' do
      config = build(:development_environment_configuration,
                    project: project,
                    anthropic_api_key: nil)
      expect(config.api_key_configured?).to be false
    end
  end

  describe 'defaults' do
    it 'sets ssh_username to "developer" by default' do
      config = create(:development_environment_configuration,
                     project: project,
                     anthropic_api_key: 'sk-test')
      expect(config.ssh_username).to eq('developer')
    end

    it 'sets ssh_port to 2222 by default' do
      config = create(:development_environment_configuration,
                     project: project,
                     anthropic_api_key: 'sk-test')
      expect(config.ssh_port).to eq(2222)
    end

    it 'sets enabled to true by default' do
      config = create(:development_environment_configuration,
                     project: project,
                     anthropic_api_key: 'sk-test')
      expect(config.enabled).to be true
    end
  end
end
