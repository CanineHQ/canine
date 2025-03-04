require 'rails_helper'

RSpec.describe K8::Metrics::Api::Node do
  describe '.parse_output' do
    context 'when the output is valid' do
      let(:output) do
        <<~OUTPUT
NAME                   CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
pool-o8jpbfqvx-gg31w   587m         7%     8963Mi          64%
pool-o8jpbfqvx-gwzng   210m         2%     5935Mi          42%
        OUTPUT
      end
      it 'parses the output' do
        result = K8::Metrics::Api::Node.parse_output(output)
        expect(result).to eq(
          [ { name: "pool-o8jpbfqvx-gg31w", cpu_cores: "587m", cpu_percent: "7%", memory_bytes: "8963Mi", memory_percent: "64%" },
           { name: "pool-o8jpbfqvx-gwzng", cpu_cores: "210m", cpu_percent: "2%", memory_bytes: "5935Mi", memory_percent: "42%" } ]
        )
      end
    end
  end
end
