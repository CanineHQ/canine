class InferJsonSchemaService
  def initialize(data)
    @data = data
    @schema = nil
  end

  def infer
    @schema ||= infer_schema(@data)
  end

  private

  def infer_schema(value)
    case value
    when Hash
      {
        "type" => "object",
        "properties" => value.transform_values { |v| infer_schema(v) }
      }
    when Array
      items_schema = value.empty? ? {} : infer_schema(value.first)
      {
        "type" => "array",
        "items" => items_schema
      }
    when String
      { "type" => "string" }
    when Integer
      { "type" => "integer" }
    when Float
      { "type" => "number" }
    when TrueClass, FalseClass
      { "type" => "boolean" }
    when NilClass
      { "type" => "null" }
    else
      {}
    end
  end
end
