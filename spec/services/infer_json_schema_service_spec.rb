require 'rails_helper'

RSpec.describe InferJsonSchemaService do
  describe '#infer' do
    it 'infers schema from Ruby object with various types' do
      data = {
        "name" => "John",
        "age" => 30,
        "score" => 95.5,
        "active" => true,
        "tags" => [ "ruby", "rails" ],
        "address" => {
          "city" => "New York",
          "zip" => 10001
        }
      }

      service = InferJsonSchemaService.new(data)
      schema = service.infer

      expect(JSON::Validator.validate(schema, data)).to be true

      invalid_data = {
        "name" => 123,
        "age" => "thirty"
      }
      expect(JSON::Validator.validate(schema, invalid_data)).to be false
    end
  end
end
