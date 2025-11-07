# frozen_string_literal: true

RSpec.shared_context 'buildpack details stubbing' do
  let(:buildpack_details_result) do
    double(
      result: Buildpacks::Details::BuildpackDetailsResult.new(
        latest: {
          version: '0.47.7',
          namespace: 'paketo-buildpacks',
          name: 'go',
          description: 'Go buildpack'
        },
        versions: []
      )
    )
  end

  before do
    allow(Buildpacks::Details).to receive(:execute).and_return(buildpack_details_result)
  end
end
