# frozen_string_literal: true

RSpec.shared_context 'with mcp enabled' do
  before do
    allow(Flipper).to receive(:enabled?).and_call_original
    allow(Flipper).to receive(:enabled?).with(:mcp_server, anything).and_return(true)
  end
end

RSpec.configure do |config|
  config.include_context 'with mcp enabled', file_path: %r{spec/mcp/}
end
