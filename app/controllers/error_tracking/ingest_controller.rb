# Sentry-compatible ingest endpoints, so official Sentry SDKs can report to a project using its DSN
# (https://<public_key>@<host>/<error_tracking_configuration_id>).
module ErrorTracking
  class IngestController < ActionController::API
    wrap_parameters false

    before_action :set_cors_headers
    before_action :set_configuration, except: :preflight

    rescue_from RequestBody::TooLarge, with: -> { render_error("Payload too large", :content_too_large) }
    rescue_from RequestBody::Invalid, Envelope::Invalid, with: ->(e) { render_error(e.message, :bad_request) }

    # A key sent in a header or the query string is checked before the body is decompressed or parsed. Only a
    # tunnelled request, whose key is solely in the envelope's DSN header, has that header line parsed first; its
    # items are still parsed only after the key matches.
    def envelope
      authenticate!(request_key || envelope_dsn_key) or return

      event_ids = parsed_envelope.events.map { |event| IngestEvent.call(@configuration, event).event_id }
      render json: { id: event_ids.first || parsed_envelope.headers["event_id"] }
    end

    def store
      authenticate!(request_key) or return

      event = JSON.parse(body)
      return render_error("Invalid event", :bad_request) unless event.is_a?(Hash)

      render json: { id: IngestEvent.call(@configuration, event).event_id }
    rescue JSON::ParserError
      render_error("Invalid JSON", :bad_request)
    end

    def preflight
      head :ok
    end

    # Bodies are binary (often gzip) and arrive with arbitrary Content-Types, so Rails must never parse them as
    # params; that happens while logging the request, before any callback runs. raw_post still reads the body.
    def process_action(*)
      request.request_parameters = {}
      super
    end

    private

    def set_configuration
      @configuration = ErrorTrackingConfiguration.find_by(id: request.path_parameters[:configuration_id])
    end

    def body
      @body ||= RequestBody.decode(request.raw_post, request.headers["Content-Encoding"])
    end

    def parsed_envelope
      @parsed_envelope ||= Envelope.parse(body)
    end

    # The key can arrive in X-Sentry-Auth, a legacy Authorization header, or the sentry_key query param (browser SDKs).
    def request_key
      auth_header = request.headers["X-Sentry-Auth"].presence || request.headers["Authorization"].to_s
      auth_header[/sentry_key=([^,\s]+)/, 1] || request.query_parameters["sentry_key"]
    end

    # Tunnelled browser requests carry the key only in the envelope header's DSN. Nothing is decoded for an unknown
    # configuration.
    def envelope_dsn_key
      return unless @configuration

      dsn = parsed_envelope.headers["dsn"]
      URI.parse(dsn).user if dsn.is_a?(String)
    rescue URI::InvalidURIError
      nil
    end

    def authenticate!(key)
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
