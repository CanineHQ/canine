# Sentry-compatible ingest endpoints, so official Sentry SDKs can report to a project using its DSN
# (https://<public_key>@<host>/<error_tracking_configuration_id>).
module ErrorTracking
  class IngestController < ActionController::API
    wrap_parameters false

    before_action :set_cors_headers
    before_action :set_configuration, except: :preflight

    rescue_from RequestBody::TooLarge, with: -> { render_error("Payload too large", :content_too_large) }
    rescue_from RequestBody::Invalid, with: ->(e) { render_error(e.message, :bad_request) }

    def envelope
      envelope = Envelope.parse(body)
      authenticate!(envelope.headers["dsn"]) or return

      event_ids = envelope.events.map { |event| IngestEvent.call(@configuration, event).event_id }
      render json: { id: event_ids.first || envelope.headers["event_id"] }
    end

    def store
      authenticate! or return

      event = JSON.parse(body)
      return render_error("Invalid event", :bad_request) unless event.is_a?(Hash)

      render json: { id: IngestEvent.call(@configuration, event).event_id }
    rescue JSON::ParserError
      render_error("Invalid JSON", :bad_request)
    end

    def preflight
      head :ok
    end

    private

    def set_configuration
      @configuration = ErrorTrackingConfiguration.find_by(id: request.path_parameters[:configuration_id])
    end

    def body
      RequestBody.decode(request.raw_post, request.headers["Content-Encoding"])
    end

    # The key can arrive in X-Sentry-Auth, a legacy Authorization header, the sentry_key query param (browser SDKs),
    # or the envelope's own DSN header (tunnelled browser requests).
    def authenticate!(envelope_dsn = nil)
      auth_header = request.headers["X-Sentry-Auth"].presence || request.headers["Authorization"].to_s
      key = auth_header[/sentry_key=([^,\s]+)/, 1] || request.query_parameters["sentry_key"]
      key ||= (URI.parse(envelope_dsn).user if envelope_dsn.is_a?(String) rescue nil)

      return true if @configuration && key.present? && ActiveSupport::SecurityUtils.secure_compare(key, @configuration.public_key)

      render_error("Invalid DSN", :unauthorized)
      false
    end

    def set_cors_headers
      response.headers["Access-Control-Allow-Origin"] = "*"
      response.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
      response.headers["Access-Control-Allow-Headers"] = "Content-Type, Content-Encoding, X-Sentry-Auth, Authorization, sentry-trace, baggage"
      response.headers["Access-Control-Expose-Headers"] = "X-Sentry-Error, Retry-After, X-Sentry-Rate-Limits"
    end

    def render_error(message, status)
      response.headers["X-Sentry-Error"] = message
      render json: { detail: message }, status:
    end
  end
end
