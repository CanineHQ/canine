# frozen_string_literal: true

module SwaggerSchemas
  def self.schemas
    constants.to_h do |constant|
      [ constant.to_s.downcase, const_get(constant) ]
    end
  end

  def self.validate!
    schemas.each do |schema_name, schema|
      next unless const_defined?(schema_name)
    end
  end
end

Dir["#{File.dirname(__FILE__)}/models/**/*.rb"].each do |file|
  require file
end
