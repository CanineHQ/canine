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

  context 'with multi-line values' do
    it 'parses double-quoted multi-line values' do
      text_content = <<~ENV
        SIMPLE=value1
        CERTIFICATE="-----BEGIN CERTIFICATE-----
        MIICpDCCAYwCCQDU+pQ4P2
        line3
        -----END CERTIFICATE-----"
        ANOTHER=value2
      ENV

      result = described_class.execute(params: { text_content: })

      expect(result.params[:environment_variables]).to eq([
        { name: 'SIMPLE', value: 'value1' },
        { name: 'CERTIFICATE', value: "-----BEGIN CERTIFICATE-----\nMIICpDCCAYwCCQDU+pQ4P2\nline3\n-----END CERTIFICATE-----" },
        { name: 'ANOTHER', value: 'value2' }
      ])
    end

    it 'parses single-quoted multi-line values' do
      text_content = <<~ENV
        KEY='line1
        line2
        line3'
      ENV

      result = described_class.execute(params: { text_content: })

      expect(result.params[:environment_variables]).to eq([
        { name: 'KEY', value: "line1\nline2\nline3" }
      ])
    end

    it 'handles mixed single-line and multi-line values' do
      text_content = <<~ENV
        DB_HOST=localhost
        SSH_KEY="-----BEGIN RSA PRIVATE KEY-----
        MIIEpAIBAAKCAQEA
        -----END RSA PRIVATE KEY-----"
        DB_PORT=5432
      ENV

      result = described_class.execute(params: { text_content: })

      expect(result.params[:environment_variables].length).to eq(3)
      expect(result.params[:environment_variables][0]).to eq({ name: 'DB_HOST', value: 'localhost' })
      expect(result.params[:environment_variables][1][:name]).to eq('SSH_KEY')
      expect(result.params[:environment_variables][1][:value]).to include("-----BEGIN RSA PRIVATE KEY-----")
      expect(result.params[:environment_variables][2]).to eq({ name: 'DB_PORT', value: '5432' })
    end

    it 'skips comments and empty lines' do
      text_content = <<~ENV
        # This is a comment
        VAR1=value1

        # Another comment
        VAR2=value2
      ENV

      result = described_class.execute(params: { text_content: })

      expect(result.params[:environment_variables]).to eq([
        { name: 'VAR1', value: 'value1' },
        { name: 'VAR2', value: 'value2' }
      ])
    end
  end

  context 'with escape sequences' do
    it 'converts \\n to actual newlines in double-quoted values' do
      text_content = 'MULTILINE="line1\\nline2\\nline3"'

      result = described_class.execute(params: { text_content: })

      expect(result.params[:environment_variables]).to eq([
        { name: 'MULTILINE', value: "line1\nline2\nline3" }
      ])
    end

    it 'converts \\t to tabs in double-quoted values' do
      text_content = 'TABBED="col1\\tcol2\\tcol3"'

      result = described_class.execute(params: { text_content: })

      expect(result.params[:environment_variables]).to eq([
        { name: 'TABBED', value: "col1\tcol2\tcol3" }
      ])
    end

    it 'preserves literal backslash-n in single-quoted values' do
      text_content = "LITERAL='line1\\nline2'"

      result = described_class.execute(params: { text_content: })

      expect(result.params[:environment_variables]).to eq([
        { name: 'LITERAL', value: 'line1\\nline2' }
      ])
    end

    it 'handles escaped quotes in double-quoted values' do
      text_content = 'QUOTED="He said \\"Hello\\""'

      result = described_class.execute(params: { text_content: })

      expect(result.params[:environment_variables]).to eq([
        { name: 'QUOTED', value: 'He said "Hello"' }
      ])
    end

    it 'handles escaped backslashes' do
      text_content = 'PATH="C:\\\\Users\\\\Name"'

      result = described_class.execute(params: { text_content: })

      expect(result.params[:environment_variables]).to eq([
        { name: 'PATH', value: 'C:\\Users\\Name' }
      ])
    end

    it 'combines multi-line with escape sequences' do
      text_content = <<~ENV
        COMPLEX="First line\\nSecond line
        Third line
        Fourth line\\nFifth line"
      ENV

      result = described_class.execute(params: { text_content: })

      expected_value = "First line\nSecond line\nThird line\nFourth line\nFifth line"
      expect(result.params[:environment_variables]).to eq([
        { name: 'COMPLEX', value: expected_value }
      ])
    end
  end
end
