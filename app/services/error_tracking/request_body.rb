# Decodes the body of a Sentry SDK request: gzip/deflate Content-Encoding, plus the legacy base64+zlib store format.
# Decompression is streamed and capped so a small compressed payload can't expand without bound.
module ErrorTracking
  class RequestBody
    class TooLarge < StandardError; end
    class Invalid < StandardError; end

    MAX_BYTES = 20.megabytes

    def self.decode(raw, content_encoding)
      raise TooLarge if raw.bytesize > MAX_BYTES

      case content_encoding.to_s.downcase.strip
      when "gzip" then gunzip(raw)
      when "deflate" then inflate(raw)
      when "", "identity" then legacy_store_body(raw)
      else raise Invalid, "Unsupported Content-Encoding: #{content_encoding}"
      end
    rescue Zlib::Error, ArgumentError => e
      raise Invalid, e.message
    end

    def self.gunzip(raw)
      body = Zlib::GzipReader.new(StringIO.new(raw)).read(MAX_BYTES + 1).to_s
      raise TooLarge if body.bytesize > MAX_BYTES
      body
    end

    def self.inflate(raw, window_bits = Zlib::MAX_WBITS)
      body = +""
      Zlib::Inflate.new(window_bits).inflate(raw) do |chunk|
        body << chunk
        raise TooLarge if body.bytesize > MAX_BYTES
      end
      body
    rescue Zlib::DataError
      # Some clients send raw deflate without the zlib header.
      raise if window_bits.negative?
      inflate(raw, -Zlib::MAX_WBITS)
    end

    # Very old SDKs post base64-encoded, zlib-compressed JSON to /store without a Content-Encoding header.
    def self.legacy_store_body(raw)
      return raw if raw.lstrip.start_with?("{") || raw.include?("\n")
      inflate(Base64.strict_decode64(raw.strip))
    rescue ArgumentError
      raw
    end
  end
end
