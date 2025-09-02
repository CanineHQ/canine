# == Schema Information
#
# Table name: build_configurations
#
#  id               :bigint           not null, primary key
#  driver           :integer          not null
#  image_repository :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  build_cloud_id   :bigint
#  project_id       :bigint           not null
#  provider_id      :bigint           not null
#
# Indexes
#
#  index_build_configurations_on_build_cloud_id  (build_cloud_id)
#  index_build_configurations_on_project_id      (project_id)
#  index_build_configurations_on_provider_id     (provider_id)
#
# Foreign Keys
#
#  fk_rails_...  (build_cloud_id => build_clouds.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (provider_id => providers.id)
#
require 'rails_helper'

RSpec.describe BuildConfiguration, type: :model do
  let(:provider) { create(:provider, :github) }
  let(:project) { create(:project) }
  let(:project_credential_provider) { create(:project_credential_provider, project:, project_credential_provider:) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_presence_of(:driver) }
    it { is_expected.to validate_presence_of(:image_repository) }
  end

  describe '#container_image_reference' do
    let(:build_configuration) { create(:build_configuration, project:, provider:, image_repository: 'czhu12/canine') }

    context 'with github provider' do
      let(:provider) { create(:provider, :github) }
      it 'returns the container image reference' do
        expect(build_configuration.container_image_reference).to eq('ghcr.io/czhu12/canine:main')
      end
    end

    context 'with gitlab provider' do
      let(:provider) { create(:provider, :gitlab) }
      it 'returns the container image reference' do
        expect(build_configuration.container_image_reference).to eq('registry.gitlab.com/czhu12/canine:main')
      end
    end

    context 'with container registry provider, but project is still git' do
      let(:provider) { create(:provider, :container_registry, registry_url: 'docker.io') }
      it 'returns the container image reference' do
        expect(build_configuration.container_image_reference).to eq('docker.io/czhu12/canine:main')
      end
    end

    context 'with credential registry provider, but project is not git' do
      let(:new_provider) { create(:provider, :custom_registry) }

      before do
        project.project_credential_provider.update(provider: new_provider)
      end

      it 'returns the container image reference with latest tag' do
        expect(build_configuration.container_image_reference).to eq('ghcr.io/czhu12/canine:latest')
      end
    end
  end
end
