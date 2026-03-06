require 'rails_helper'

RSpec.describe K8::Stateless::ConfigMap do
  let(:project) { create(:project) }
  let(:config_map) { described_class.new(project) }

  describe '#to_yaml' do
    context 'with single-line environment variables' do
      before do
        create(:environment_variable, project: project, name: 'SIMPLE_VAR', value: 'simple value', storage_type: :config)
        create(:environment_variable, project: project, name: 'QUOTED_VAR', value: 'value with "quotes"', storage_type: :config)
      end

      it 'generates valid YAML with quoted values' do
        yaml_output = config_map.to_yaml
        parsed = YAML.safe_load(yaml_output)

        expect(parsed['kind']).to eq('ConfigMap')
        expect(parsed['data']['SIMPLE_VAR']).to eq('simple value')
        expect(parsed['data']['QUOTED_VAR']).to eq('value with "quotes"')
      end
    end

    context 'with multi-line environment variables' do
      before do
        certificate = <<~CERT.strip
          -----BEGIN CERTIFICATE-----
          MIICpDCCAYwCCQDU+pQ4P2
          line3
          -----END CERTIFICATE-----
        CERT
        create(:environment_variable, project: project, name: 'CERTIFICATE', value: certificate, storage_type: :config)
        create(:environment_variable, project: project, name: 'SIMPLE', value: 'value1', storage_type: :config)
      end

      it 'generates valid YAML with multi-line block scalar syntax' do
        yaml_output = config_map.to_yaml
        parsed = YAML.safe_load(yaml_output)

        expect(parsed['kind']).to eq('ConfigMap')
        expect(parsed['data']['SIMPLE']).to eq('value1')
        expect(parsed['data']['CERTIFICATE']).to include('-----BEGIN CERTIFICATE-----')
        expect(parsed['data']['CERTIFICATE']).to include('-----END CERTIFICATE-----')
        expect(parsed['data']['CERTIFICATE'].lines.count).to eq(4)
      end

      it 'preserves newlines in multi-line values' do
        yaml_output = config_map.to_yaml
        parsed = YAML.safe_load(yaml_output)

        lines = parsed['data']['CERTIFICATE'].lines.map(&:chomp)
        expect(lines[0]).to eq('-----BEGIN CERTIFICATE-----')
        expect(lines[1]).to eq('MIICpDCCAYwCCQDU+pQ4P2')
        expect(lines[2]).to eq('line3')
        expect(lines[3]).to eq('-----END CERTIFICATE-----')
      end
    end

    context 'with only secret environment variables' do
      before do
        create(:environment_variable, project: project, name: 'SECRET_VAR', value: 'secret', storage_type: :secret)
      end

      it 'does not include secret variables in ConfigMap' do
        yaml_output = config_map.to_yaml
        parsed = YAML.safe_load(yaml_output)

        expect(parsed['data']).to be_nil
      end
    end
  end
end
