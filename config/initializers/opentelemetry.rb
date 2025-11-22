# frozen_string_literal: true

# Only configure OpenTelemetry when explicitly enabled and an endpoint is provided
if ENV['OTEL_ENABLED'] == 'true' && ENV['OTEL_EXPORTER_OTLP_ENDPOINT'].present?
  require 'opentelemetry/sdk'
  require 'opentelemetry-exporter-otlp'

  OpenTelemetry::SDK.configure do |c|
    # Configure service name
    c.service_name = ENV.fetch('OTEL_SERVICE_NAME', 'canine')
    c.service_version = ENV.fetch('OTEL_SERVICE_VERSION', '1.0.0')

    # Add resource attributes - ensure all values are strings, integers, floats, or booleans
    c.resource = OpenTelemetry::SDK::Resources::Resource.create(
      'deployment.environment' => Rails.env.to_s,
      'service.namespace' => 'canine',
      'host.name' => Socket.gethostname.to_s
    )

    # Configure OTLP exporter
    # Required environment variables:
    # - OTEL_ENABLED=true
    # - OTEL_EXPORTER_OTLP_ENDPOINT (e.g., "http://localhost:4318")
    # Optional: OTEL_EXPORTER_OTLP_HEADERS (e.g., "api-key=secret")
    c.add_span_processor(
      OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
        OpenTelemetry::Exporter::OTLP::Exporter.new
      )
    )

    # Configure instrumentation libraries
    c.use 'OpenTelemetry::Instrumentation::Rails'
    c.use 'OpenTelemetry::Instrumentation::ActiveJob'
    c.use 'OpenTelemetry::Instrumentation::ActiveRecord'
    c.use 'OpenTelemetry::Instrumentation::ActionPack'
    c.use 'OpenTelemetry::Instrumentation::ActionView'
    c.use 'OpenTelemetry::Instrumentation::ActiveSupport'
    c.use 'OpenTelemetry::Instrumentation::Rack'
    c.use 'OpenTelemetry::Instrumentation::Http'
    c.use 'OpenTelemetry::Instrumentation::PG'
  end
end
