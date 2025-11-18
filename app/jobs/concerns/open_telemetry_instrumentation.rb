# frozen_string_literal: true

module OpenTelemetryInstrumentation
  extend ActiveSupport::Concern

  included do
    around_perform :instrument_job_execution
  end

  private

  def instrument_job_execution
    tracer = OpenTelemetry.tracer_provider.tracer('canine.jobs', '1.0.0')

    tracer.in_span(
      "#{self.class.name}#perform",
      attributes: {
        'job.class' => self.class.name,
        'job.queue' => queue_name,
        'job.id' => job_id,
        'job.provider_job_id' => provider_job_id,
        'job.executions' => executions,
        'job.arguments' => sanitized_arguments
      },
      kind: :internal
    ) do |span|
      start_time = Time.current

      begin
        yield

        # Record successful execution metrics
        span.set_attribute('job.status', 'success')
        span.set_attribute('job.duration_ms', (Time.current - start_time) * 1000)
        span.status = OpenTelemetry::Trace::Status.ok
      rescue StandardError => e
        # Record failure metrics
        span.set_attribute('job.status', 'failed')
        span.set_attribute('job.duration_ms', (Time.current - start_time) * 1000)
        span.set_attribute('job.error.class', e.class.name)
        span.set_attribute('job.error.message', e.message)
        span.record_exception(e)
        span.status = OpenTelemetry::Trace::Status.error("Job failed: #{e.message}")

        raise
      end
    end
  end

  def sanitized_arguments
    # Sanitize arguments to avoid logging sensitive data
    arguments.map do |arg|
      case arg
      when ActiveRecord::Base
        "#{arg.class.name}##{arg.id}"
      when Hash
        arg.keys.join(',')
      else
        arg.class.name
      end
    end.join(', ')
  end
end
