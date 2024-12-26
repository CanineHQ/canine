module DotSettable
  def dotset(path, value)
    keys = path.split(".")
    last_key = keys.pop
    nested_hash = keys.inject(self) { |current_hash, key| current_hash[key] ||= {} }
    nested_hash[last_key] = value
  end
end
