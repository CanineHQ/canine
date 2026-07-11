# frozen_string_literal: true

module ContainerRegistry
  class ImageChecker
    Result = Struct.new(:valid, :error, keyword_init: true)

    def self.check(image_url)
      new(image_url).check
    end

    def initialize(image_url)
      @raw_url = image_url.to_s.strip
    end

    def check
      return Result.new(valid: false, error: "Image URL is required") if @raw_url.blank?

      parse_image_url
      token = fetch_auth_token
      check_manifest(token)
    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      Result.new(valid: false, error: "Could not connect to registry #{@registry}")
    rescue Net::OpenTimeout, Net::ReadTimeout
      Result.new(valid: false, error: "Connection to registry #{@registry} timed out")
    rescue StandardError => e
      Result.new(valid: false, error: e.message)
    end

    private

    def parse_image_url
      url = @raw_url

      # Extract tag
      last_colon = url.rindex(":")
      if last_colon && !url[last_colon..].include?("/")
        @tag = url[(last_colon + 1)..]
        url = url[0...last_colon]
      else
        @tag = "latest"
      end

      # Split into registry and repository
      parts = url.split("/")
      if parts.first&.match?(/[.:]/)
        @registry = parts.first
        @repository = parts[1..].join("/")
      else
        @registry = "registry-1.docker.io"
        @repository = parts.length == 1 ? "library/#{parts.first}" : parts.join("/")
      end
    end

    def fetch_auth_token
      return nil unless @registry == "registry-1.docker.io"

      uri = URI("https://auth.docker.io/token?service=registry.docker.io&scope=repository:#{@repository}:pull")
      response = Net::HTTP.get_response(uri)
      return nil unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)["token"]
    end

    def check_manifest(token)
      uri = URI("https://#{@registry}/v2/#{@repository}/manifests/#{@tag}")
      request = Net::HTTP::Head.new(uri)
      request["Accept"] = "application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.manifest.v1+json"
      request["Authorization"] = "Bearer #{token}" if token

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
        http.request(request)
      end

      case response
      when Net::HTTPSuccess
        Result.new(valid: true)
      when Net::HTTPUnauthorized, Net::HTTPForbidden
        Result.new(valid: false, error: "Image requires authentication — use a private registry instead")
      when Net::HTTPNotFound
        Result.new(valid: false, error: "Image '#{@repository}:#{@tag}' not found on #{@registry}")
      else
        Result.new(valid: false, error: "Registry returned #{response.code}")
      end
    end
  end
end
