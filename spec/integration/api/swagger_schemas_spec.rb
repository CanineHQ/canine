# frozen_string_literal: true

require 'rails_helper'
require './spec/integration/api/swagger_schemas'

RSpec.describe SwaggerSchemas do
  it 'matches' do
    expect { described_class.validate! }.not_to raise_error
  end
end
