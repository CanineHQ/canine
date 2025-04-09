module StorageHelper
  SIZE_UNITS = {
    'K' => 1024,
    'M' => 1024**2,
    'G' => 1024**3,
    'T' => 1024**4
  }

  def integer_to_compute(integer)
    integer.to_s + 'm'
  end

  def compute_to_integer(compute)
    if compute.end_with?("m")
      compute = compute.strip.gsub(/m$/, '')
      compute.to_i
    else
      (compute.to_f * 1000).to_i
    end
  end

  def memory_to_integer(size)
    size = size.strip
    match = size.match(/^(\d+(?:\.\d+)?)\s*([KMGTkmgt]i?)?$/)
    return nil unless match

    value = match[1].to_f
    unit = match[2]&.upcase&.chr || ''

    (value * (SIZE_UNITS[unit] || 1)).to_i
  end

  def integer_to_memory(integer)
    SIZE_UNITS.to_a.reverse.each do |unit, bytes|
      if integer >= bytes
        value = (integer.to_f / bytes).round(2)
        return "#{value}#{unit}i"
      end
    end
    integer.to_s
  end

  def standardize_size(size)
    integer_to_memory(memory_to_integer(size)).to_s
  end
end
