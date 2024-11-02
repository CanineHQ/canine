module StorageHelper
  SIZE_UNITS = {
    'K' => 1024,
    'M' => 1024**2,
    'G' => 1024**3,
    'T' => 1024**4
  }

  def size_to_integer(size)
    size = size.strip
    match = size.match(/^(\d+(?:\.\d+)?)\s*([KMGTkmgt]i?)?$/)
    return nil unless match

    value = match[1].to_f
    unit = match[2]&.upcase&.chr || ''
    
    (value * (SIZE_UNITS[unit] || 1)).to_i
  end

  def integer_to_size(integer)
    SIZE_UNITS.to_a.reverse.each do |unit, bytes|
      if integer >= bytes
        value = (integer.to_f / bytes).round(2)
        return "#{value}#{unit}i"
      end
    end
    integer.to_s
  end

  def standardize_size(size)
    integer_to_size(size_to_integer(size)).to_s
  end
end