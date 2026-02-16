require 'rails_helper'

RSpec.describe AddOns::ApplyTemplateToValues do
  let(:add_on) { build(:add_on) }
  let(:template) do
    {
      'master.persistence.size' => { 'type' => 'size', 'value' => '10', 'unit' => 'Gi' },
      'replica.replicaCount' => '5'
    }
  end

  before do
    add_on.metadata['template'] = template
  end

  it 'applies template values correctly' do
    described_class.execute(add_on:)
    expect(add_on.values['master']['persistence']['size']).to eq('10Gi')
    expect(add_on.values['replica']['replicaCount']).to eq(5)
  end
end
