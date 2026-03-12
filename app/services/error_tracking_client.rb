class ErrorTrackingClient
  class Error < StandardError; end

  def initialize(base_url)
    @base_url = base_url.chomp("/")
  end

  def sources
    get("/api/sources")
  end

  def create_source(name:, platform: nil)
    post("/api/sources", { name: name, platform: platform })
  end

  def events(source_id, limit: 100)
    get("/api/sources/#{source_id}/events?limit=#{limit}")
  end

  private

  def get(path)
    uri = URI("#{@base_url}#{path}")
    response = Net::HTTP.get_response(uri)
    parse(response)
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError, Timeout::Error => e
    raise Error, "Cannot reach error tracking service: #{e.message}"
  end

  def post(path, body)
    uri = URI("#{@base_url}#{path}")
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = body.to_json
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) do |http|
      http.request(request)
    end
    parse(response)
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError, Timeout::Error => e
    raise Error, "Cannot reach error tracking service: #{e.message}"
  end

  def parse(response)
    JSON.parse(response.body)
  rescue JSON::ParserError
    raise Error, "Invalid response from error tracking service"
  end
end
