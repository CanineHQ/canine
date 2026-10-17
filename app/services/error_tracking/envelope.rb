# Parses the Sentry envelope format: a JSON header line followed by items, each an item-header JSON line and a
# payload that is either `length` bytes long or runs to the next newline.
# https://develop.sentry.dev/sdk/data-model/envelopes/
#
# Only the header line is parsed up front, so a request can be authenticated by the header's DSN before the
# (untrusted, possibly large) items are read.
module ErrorTracking
  class Envelope
    class Invalid < StandardError; end

    Item = Struct.new(:type, :payload, keyword_init: true)
    MAX_ITEMS = 100

    attr_reader :headers

    def self.parse(body)
      new(body.b)
    end

    def initialize(body)
      @body = body
      @pos = 0
      @headers = parse_json(read_line) || {}
    end

    def items
      @items ||= begin
        items = []
        while @pos < @body.bytesize
          line = read_line
          next if line.strip.empty?
          raise Invalid, "Too many envelope items" if items.size >= MAX_ITEMS

          item_headers = parse_json(line) || {}
          payload = item_headers.key?("length") ? read_bytes(item_headers["length"]) : read_line
          items << Item.new(type: item_headers["type"], payload: payload)
        end
        items
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

    # The length must move the cursor forward within the body; anything else (negative, fractional, too large, not a
    # number) would let a crafted envelope loop or read out of bounds.
    def read_bytes(length)
      unless length.is_a?(Integer) && length.between?(0, @body.bytesize - @pos)
        raise Invalid, "Invalid envelope item length"
      end

      bytes = @body.byteslice(@pos, length)
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
