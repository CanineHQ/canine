# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Projects::UpdateBuildPacks do
  include_context 'buildpack details stubbing'

  let(:provider) { create(:provider, :github) }
  let(:project) { create(:project) }
  let(:build_configuration) do
    create(:build_configuration,
           project: project,
           provider: provider,
           build_type: :buildpacks,
           buildpack_base_builder: 'paketobuildpacks/builder:full')
  end

  let!(:existing_ruby) do
    create(
      :build_pack,
      build_configuration: build_configuration,
      namespace: 'paketo-buildpacks',
      name: 'ruby',
      reference_type: 'registry',
      build_order: 0,
    )
  end

  let!(:existing_nodejs) do
    create(
      :build_pack,
      build_configuration: build_configuration,
      namespace: 'paketo-buildpacks',
      name: 'nodejs',
      reference_type: 'registry',
      build_order: 1,
    )
  end

  let(:params) do
    ActionController::Parameters.new({
      project: {
        build_configuration: {
          build_packs_attributes: [
            {
              namespace: 'paketo-buildpacks',
              name: 'go',
              version: '',
              reference_type: 'registry'
            },
            {
              namespace: 'paketo-buildpacks',
              name: 'ruby',
              version: '',
              reference_type: 'registry'
            }
          ]
        }
      }
    })
  end

  let(:context) do
    {
      build_configuration: build_configuration,
      params: params
    }
  end

  it 'keeps existing build packs, creates new ones, and deletes missing ones' do
    expect(build_configuration.build_packs.map(&:key)).to eq([ 'paketo-buildpacks/ruby', 'paketo-buildpacks/nodejs' ])
    described_class.execute(context)
    build_configuration.build_packs.reload
    expect(build_configuration.build_packs.map(&:key)).to eq([ 'paketo-buildpacks/go', 'paketo-buildpacks/ruby' ])
  end
end
