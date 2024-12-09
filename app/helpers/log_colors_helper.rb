module LogColorsHelper
  ANSI_TO_TAILWIND = {
    "0" => "text-gray-300",   # Reset or default
    "1" => "font-bold",       # Bold
    "2" => "text-gray-500",   # Dim
    "31" => "text-red-400",   # Red (lighter for dark background)
    "32" => "text-green-400", # Green (lighter)
    "33" => "text-yellow-300", # Yellow (lighter)
    "34" => "text-blue-400",  # Blue (lighter)
    "35" => "text-purple-400", # Magenta (lighter)
    "36" => "text-cyan-400",  # Cyan (lighter)
    "90" => "text-gray-500",  # Bright Black (Gray)
    "97" => "text-gray-100"  # White (almost pure white)
    # Add more mappings as needed...
  }

  FRIENDLY_COLORS = {
    bold: "1",
    dim: "2",
    red: "31",
    green: "32",
    yellow: "33",
    blue: "34",
    magenta: "35",
    cyan: "36",
    gray: "90",
    white: "97"
  }.tap do |colors|
    colors.default = "0"
  end

  def ansi_to_tailwind(log)
    # Match ANSI escape codes and replace them with Tailwind classes
    log.gsub(/\e\[(\d+)(;\d+)*m/) do
      codes = $&.scan(/\d+/)  # Extract all ANSI code numbers
      classes = codes.map { |code| ANSI_TO_TAILWIND[code] }.compact.join(" ")
      "<span class=\"#{classes}\">"
    end + "</span>" # Add closing span tag at the end
  end
end
