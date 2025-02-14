require 'rails_helper'

RSpec.describe Loggable do
  let(:instance) { create(:cluster) }

  describe '#info' do
    it 'logs info messages and creates a log_output' do
      expect {
        instance.info('Test info message', color: :green)
      }.to change { LogOutput.count }.by(1)

      log_output = LogOutput.last
      expect(log_output.output).to include("\e[32mTest info message\e[0m")
    end
  end
end
