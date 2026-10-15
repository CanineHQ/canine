module ErrorTracking
  def self.table_name_prefix
    "error_tracking_"
  end

  # Event payloads come from many SDKs and versions, so reads must tolerate unexpected shapes instead of raising.

  # Interfaces such as exception and breadcrumbs arrive either as {"values" => [...]} or as the bare list.
  def self.values(interface)
    list = interface.is_a?(Hash) ? interface["values"] : interface
    Array.wrap(list).select { |value| value.is_a?(Hash) }
  end

  # Hash#dig that returns nil, rather than raising, when an intermediate value is not a hash.
  def self.dig(data, *keys)
    keys.reduce(data) { |value, key| value.is_a?(Hash) ? value[key] : (break nil) }
  end
end
