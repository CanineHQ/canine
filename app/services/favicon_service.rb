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

  # Returns the best available favicon URL, trying multiple providers
  def fetch_best_url(size: 64)
    return nil if @domain.blank?

    # DuckDuckGo is preferred as it doesn't return a default image
    # Google always returns something, even if it's just their default globe
    duckduckgo_favicon_url
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
end
