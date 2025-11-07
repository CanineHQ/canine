# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Projects::InitializeBuildPacks do
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

  let(:params) do
    ActionController::Parameters.new({
      project: {
        build_configuration: {
          build_packs_attributes: [
            {
              namespace: 'paketo-buildpacks',
              name: 'ruby',
              version: '0.47.7',
              reference_type: 'registry'
            },
            {
              namespace: 'paketo-buildpacks',
              name: 'nodejs',
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

  subject { described_class.execute(context) }

  it 'builds build packs from attributes' do
    expect { subject }.to change { build_configuration.build_packs.size }.from(0).to(2)

    first_pack = build_configuration.build_packs[0]
    expect(first_pack.namespace).to eq('paketo-buildpacks')
    expect(first_pack.name).to eq('ruby')
    expect(first_pack.version).to eq('0.47.7')
    expect(first_pack.reference_type).to eq('registry')

    second_pack = build_configuration.build_packs[1]
    expect(second_pack.namespace).to eq('paketo-buildpacks')
    expect(second_pack.name).to eq('nodejs')
    expect(second_pack.version).to eq('')
    expect(second_pack.reference_type).to eq('registry')
  end
end
