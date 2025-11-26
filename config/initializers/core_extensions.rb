# frozen_string_literal: true

class Hash
  # Converts hash to YAML without the document start marker (---)
  def to_yaml_raw
    to_yaml.sub(/\A---\n?/, "")
  end
end
