# frozen_string_literal: true

module ContainerRegistry
  class ImageChecker
    Result = Struct.new(:valid, :error, keyword_init: true)

    TIMEOUT = 10

    def self.check(image_url)
      new(image_url).check
    end

    def initialize(image_url)
      @image_url = image_url.to_s.strip
    end

    def check
      return Result.new(valid: false, error: "Image URL is required") if @image_url.blank?

      _stdout, stderr, status = Timeout.timeout(TIMEOUT) do
        Open3.capture3("docker", "manifest", "inspect", @image_url)
      end

      if status.success?
        Result.new(valid: true)
      else
        Result.new(valid: false, error: parse_error(stderr))
      end
    rescue Timeout::Error, Errno::ETIMEDOUT
      Result.new(valid: false, error: "Timed out checking image")
    rescue StandardError => e
      Result.new(valid: false, error: e.message)
    end

    private

    def parse_error(stderr)
      msg = stderr.to_s.strip
      if msg.include?("not found") || msg.include?("manifest unknown")
        "Image not found"
      elsif msg.include?("unauthorized") || msg.include?("denied")
        "Image requires authentication — use a private registry instead"
      elsif msg.include?("no such host") || msg.include?("connection refused")
        "Could not connect to registry"
      else
        "Image could not be verified"
      end
    end
  end
end
