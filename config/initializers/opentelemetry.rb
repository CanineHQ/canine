# frozen_string_literal: true

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

  # Configure OTLP exporter (default: http://localhost:4318)
  # Can be configured via environment variables:
  # OTEL_EXPORTER_OTLP_ENDPOINT - full endpoint URL
  # OTEL_EXPORTER_OTLP_HEADERS - headers (e.g., "api-key=secret")
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
