# == Schema Information
#
# Table name: build_packs
#
#  id                     :bigint           not null, primary key
#  build_order            :integer          not null
#  details                :jsonb
#  name                   :string
#  namespace              :string
#  reference_type         :integer          not null
#  uri                    :text
#  version                :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  build_configuration_id :bigint           not null
#
# Indexes
#
#  index_build_packs_on_build_configuration_id      (build_configuration_id)
#  index_build_packs_on_config_type_namespace_name  (build_configuration_id,reference_type,namespace,name)
#  index_build_packs_on_config_uri                  (build_configuration_id,uri)
#
# Foreign Keys
#
#  fk_rails_...  (build_configuration_id => build_configurations.id)
#
require 'rails_helper'

RSpec.describe BuildPack, type: :model do
  describe '#reference' do
    context 'registry buildpack' do
      let(:build_pack) { create(:build_pack) }

      context 'when version is present' do
        before { build_pack.update(version: '0.47.7') }

        it 'returns namespace/name:version' do
          expect(build_pack.reference).to eq('paketo-buildpacks/ruby:0.47.7')
        end
      end

      context 'when version is not present' do
        before { build_pack.update(version: nil) }

        it 'returns namespace/name' do
          expect(build_pack.reference).to eq('paketo-buildpacks/ruby')
        end
      end
    end

    context 'git buildpack' do
      let(:build_pack) { create(:build_pack, :git) }

      it 'returns the git URL' do
        expect(build_pack.reference).to eq('https://github.com/DataDog/heroku-buildpack-datadog.git')
      end
    end

    context 'url buildpack' do
      let(:build_pack) { create(:build_pack, :url) }

      it 'returns the URL' do
        expect(build_pack.reference).to eq('https://github.com/heroku/buildpacks-ruby/releases/download/v0.1.0/buildpack.tgz')
      end
    end
  end

  describe '#verified?' do
    it 'returns true for registry buildpacks with verified namespaces' do
      build_pack = create(:build_pack, namespace: 'paketo-buildpacks')
      expect(build_pack.verified?).to be true
    end

    it 'returns false for registry buildpacks with unverified namespaces' do
      build_pack = create(:build_pack, namespace: 'custom-buildpacks')
      expect(build_pack.verified?).to be false
    end

    it 'returns false for git buildpacks' do
      build_pack = create(:build_pack, :git)
      expect(build_pack.verified?).to be false
    end
  end

  describe '#display_name' do
    it 'returns namespace/name for registry buildpacks' do
      build_pack = create(:build_pack)
      expect(build_pack.display_name).to eq('paketo-buildpacks/ruby')
    end

    it 'returns repo name for git buildpacks' do
      build_pack = create(:build_pack, :git)
      expect(build_pack.display_name).to eq('heroku-buildpack-datadog')
    end
  end
end
