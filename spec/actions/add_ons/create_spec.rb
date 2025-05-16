require 'rails_helper'

RSpec.describe AddOns::Create do
  let(:add_on) { build(:add_on) }
  let(:context) { LightService::Context.new(add_on: add_on) }
  let(:chart_details) { { 'name' => 'test-chart', 'version' => '1.0.0' } }

  before do
    allow(AddOns::HelmChartDetails).to receive(:execute).and_return(
      double(success?: true, failure?: false, response: chart_details)
    )
  end

  describe '#execute' do
    it 'applies template and fetches package details' do
      expect(add_on).to receive(:save)
      result = described_class.execute(context)
      expect(result.add_on.metadata['package_details']).to eq(chart_details)
    end

    context 'when package details fetch fails' do
      before do
        allow(AddOns::HelmChartDetails).to receive(:execute).and_return(
          double(success?: false, failure?: true)
        )
      end

      it 'adds error and returns' do
        result = described_class.execute(context)
        expect(result.add_on.errors[:base]).to include('Failed to fetch package details')
      end
    end
  end

  describe '.apply_template_to_values' do
    let(:template) do
      {
        'size_var' => { 'type' => 'size', 'value' => '10', 'unit' => 'Gi' },
        'int_var' => '5',
        'str_var' => 'test'
      }
    end

    before do
      add_on.metadata['template'] = template
      add_on.chart_definition = {
        'template' => [
          { 'key' => 'int_var', 'type' => 'integer' },
          { 'key' => 'str_var', 'type' => 'string' }
        ]
      }
    end

    it 'applies template values correctly' do
      described_class.apply_template_to_values(add_on)
      expect(add_on.values.dotset('size_var')).to eq('10Gi')
      expect(add_on.values.dotset('int_var')).to eq(5)
      expect(add_on.values.dotset('str_var')).to eq('test')
    end
  end
end 