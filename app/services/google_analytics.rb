class GoogleAnalytics
  URL = "https://www.google-analytics.com/mp/collect"

  def self.track(event_name, client_id:, params: {})
    return unless enabled?

    uri = URI("#{URL}?measurement_id=#{ENV["GOOGLE_ANALYTICS_ID"]}&api_secret=#{ENV["GOOGLE_ANALYTICS_API_SECRET"]}")
    body = {
      client_id: client_id,
      events: [ { name: event_name, params: params } ]
    }.to_json

    Thread.new do
      Net::HTTP.post(uri, body, "Content-Type" => "application/json")
    rescue => e
      Rails.logger.warn("GA4 tracking failed: #{e.message}")
    end
  end

  def self.enabled?
    ENV["GOOGLE_ANALYTICS_ID"].present? && ENV["GOOGLE_ANALYTICS_API_SECRET"].present?
  end
end
