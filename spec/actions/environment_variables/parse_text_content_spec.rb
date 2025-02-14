require 'rails_helper'

RSpec.describe EnvironmentVariables::ParseTextContent do
  context 'when text_content is present' do
    let(:params) { { text_content: "VAR1=value1\nVAR2=\"value2\"" } }
    it 'parses text content into environment variables' do
      result = described_class.execute(params:)

      expect(result.params[:environment_variables]).to eq([
        { name: 'VAR1', value: 'value1' },
        { name: 'VAR2', value: 'value2' }
      ])
    end
  end

  context 'when text_content is blank' do
    let(:params) { { text_content: "" } }

    it 'does not modify context if text_content is blank' do
      result = described_class.execute(params:)

      expect(result.params[:environment_variables]).to be_nil
    end
  end
end
