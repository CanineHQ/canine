class FaviconService
  GOOGLE_FAVICON_URL = "https://www.google.com/s2/favicons"
  DUCKDUCKGO_FAVICON_URL = "https://icons.duckduckgo.com/ip3"

  def initialize(domain)
    @domain = clean_domain(domain)
  end

  def fetch_url(size: 64, provider: :duckduckgo)
    return nil if @domain.blank?

    case provider
    when :google
      google_favicon_url(size)
    when :duckduckgo
      duckduckgo_favicon_url
    when :direct
      direct_favicon_url
    else
      duckduckgo_favicon_url
    end
  end

  def exists?(size: 64, provider: :direct)
    return false if @domain.blank?

    url = case provider
    when :direct
            direct_favicon_url
    when :google
            google_favicon_url(size)
    when :duckduckgo
            duckduckgo_favicon_url
    else
            direct_favicon_url
    end

    check_favicon_exists(url)
  end

  private

  def clean_domain(domain)
    return nil if domain.blank?

    # Remove protocol if present
    domain = domain.sub(%r{^https?://}, '')
    # Remove path if present
    domain = domain.split('/').first
    # Remove port if present
    domain = domain.split(':').first
    # Remove www if present (optional, depending on preference)
    domain = domain.sub(/^www\./, '')

    domain
  end

  def google_favicon_url(size)
    "#{GOOGLE_FAVICON_URL}?domain=#{@domain}&sz=#{size}"
  end

  def duckduckgo_favicon_url
    "#{DUCKDUCKGO_FAVICON_URL}/#{@domain}.ico"
  end

  def direct_favicon_url
    "https://#{@domain}/favicon.ico"
  end

  def check_favicon_exists(url)
    require 'net/http'
    require 'uri'

    begin
      uri = URI.parse(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 2, read_timeout: 2) do |http|
        http.head(uri.path.empty? ? '/' : uri.path + (uri.query ? "?#{uri.query}" : ''))
      end

      # Check if response is successful (2xx) or redirect (3xx)
      response.code.to_i >= 200 && response.code.to_i < 400
    rescue StandardError
      # Return false for any network errors, timeouts, etc.
      false
    end
  end
end
