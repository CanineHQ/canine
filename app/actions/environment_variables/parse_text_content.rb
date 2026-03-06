class EnvironmentVariables::ParseTextContent
  extend LightService::Action

  expects :params
  promises :params

  executed do |context|
    unless context.params[:text_content].present?
      next
    end

    context.params[:environment_variables] = parse_env_content(context.params[:text_content])
  end

  private

  # Parses .env file content supporting multi-line values
  # Supports:
  #   - Simple: KEY=value
  #   - Quoted: KEY="value with spaces"
  #   - Multi-line with quotes: KEY="line1
  #     line2
  #     line3"
  #   - Single quotes: KEY='value'
  def self.parse_env_content(content)
    variables = []
    lines = content.lines
    i = 0

    while i < lines.length
      line = lines[i].chomp

      # Skip empty lines and comments
      if line.strip.empty? || line.strip.start_with?('#')
        i += 1
        next
      end

      # Match KEY=value pattern
      match = line.match(/\A([A-Za-z_][A-Za-z0-9_]*)=(.*)?\z/)
      unless match
        i += 1
        next
      end

      name = match[1]
      value_part = match[2] || ""

      # Check if value starts with a quote
      if value_part.start_with?('"')
        # Multi-line double-quoted value
        value, lines_consumed = parse_quoted_value(lines, i, '"')
        variables << { name:, value: }
        i += lines_consumed
      elsif value_part.start_with?("'")
        # Multi-line single-quoted value
        value, lines_consumed = parse_quoted_value(lines, i, "'")
        variables << { name:, value: }
        i += lines_consumed
      else
        # Simple unquoted value
        variables << { name:, value: value_part.strip }
        i += 1
      end
    end

    variables
  end

  # Parses a quoted value that may span multiple lines
  def self.parse_quoted_value(lines, start_index, quote_char)
    line = lines[start_index].chomp
    # Extract everything after the = and opening quote
    match = line.match(/\A[A-Za-z_][A-Za-z0-9_]*=#{Regexp.escape(quote_char)}(.*)/)
    return [ "", 1 ] unless match

    value_content = match[1]

    # Check if the closing quote is on the same line
    if value_content.end_with?(quote_char)
      final_value = value_content[0...-1]
      # Process escape sequences for double-quoted values
      final_value = unescape_value(final_value) if quote_char == '"'
      return [ final_value, 1 ]
    end

    # Multi-line: collect lines until we find the closing quote
    collected = [ value_content ]
    lines_consumed = 1
    current_index = start_index + 1

    while current_index < lines.length
      current_line = lines[current_index].chomp
      lines_consumed += 1

      if current_line.end_with?(quote_char)
        # Found closing quote
        collected << current_line[0...-1]
        break
      else
        collected << current_line
      end

      current_index += 1
    end

    final_value = collected.join("\n")
    # Process escape sequences for double-quoted values
    final_value = unescape_value(final_value) if quote_char == '"'
    [ final_value, lines_consumed ]
  end

  # Unescapes common escape sequences in double-quoted strings
  # Supports: \n (newline), \t (tab), \r (carriage return), \\ (backslash), \" (quote)
  def self.unescape_value(value)
    value.gsub(/\\(.)/) do |match|
      case $1
      when 'n' then "\n"
      when 't' then "\t"
      when 'r' then "\r"
      when '\\' then '\\'
      when '"' then '"'
      else match # Keep unknown escape sequences as-is
      end
    end
  end
end
