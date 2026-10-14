# Parses the Sentry envelope format: a JSON header line followed by items, each an item-header JSON line and a
# payload that is either `length` bytes long or runs to the next newline.
# https://develop.sentry.dev/sdk/data-model/envelopes/
module ErrorTracking
  class Envelope
    Item = Struct.new(:type, :payload, keyword_init: true)

    attr_reader :headers, :items

    def self.parse(body)
      new(body.b)
    end

    def initialize(body)
      @body = body
      @pos = 0
      @headers = parse_json(read_line) || {}
      @items = []
      while @pos < @body.bytesize
        line = read_line
        next if line.strip.empty?
        item_headers = parse_json(line) || {}
        length = item_headers["length"]
        payload = length ? read_bytes(length.to_i) : read_line
        @items << Item.new(type: item_headers["type"], payload: payload)
      end
    end

    def events
      items.select { |item| item.type == "event" }.filter_map { |item| parse_json(item.payload) }
    end

    private

    def read_line
      newline = @body.index("\n", @pos) || @body.bytesize
      line = @body.byteslice(@pos, newline - @pos)
      @pos = newline + 1
      line
    end

    def read_bytes(length)
      bytes = @body.byteslice(@pos, length).to_s
      @pos += length
      @pos += 1 if @body.getbyte(@pos) == "\n".ord
      bytes
    end

    def parse_json(string)
      value = JSON.parse(string.to_s.force_encoding(Encoding::UTF_8).scrub)
      value if value.is_a?(Hash)
    rescue JSON::ParserError
      nil
    end
  end
end
