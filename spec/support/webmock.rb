# frozen_string_literal: true

require 'webmock/rspec'

RSpec.configure do |config| # rubocop:disable Metrics/BlockLength
  config.before(:each) do
    WebMock.disable_net_connect!(allow_localhost: true)
  end
end
