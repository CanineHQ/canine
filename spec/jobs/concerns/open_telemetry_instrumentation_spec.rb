# frozen_string_literal: true

require "rails_helper"

RSpec.describe OpenTelemetryInstrumentation, type: :job do
  # Create a test job class
  let(:test_job_class) do
    Class.new(ApplicationJob) do
      def perform(should_fail: false)
        raise StandardError, "Test error" if should_fail
        "success"
      end
    end
  end

  let(:mock_tracer) { instance_double(OpenTelemetry::Trace::Tracer) }
  let(:mock_span) { instance_double(OpenTelemetry::Trace::Span) }

  before do
    allow(OpenTelemetry).to receive_message_chain(:tracer_provider, :tracer).and_return(mock_tracer)
    allow(mock_tracer).to receive(:in_span).and_yield(mock_span)
    allow(mock_span).to receive(:set_attribute)
    allow(mock_span).to receive(:status=)
    allow(mock_span).to receive(:record_exception)
  end

  describe "successful job execution" do
    it "instruments job with success metrics" do
      expect(mock_tracer).to receive(:in_span).with(
        /perform/,
        hash_including(
          attributes: hash_including('job.class', 'job.queue'),
          kind: :internal
        )
      ).and_yield(mock_span)

      expect(mock_span).to receive(:set_attribute).with('job.status', 'success')
      expect(mock_span).to receive(:set_attribute).with('job.duration_ms', anything)
      expect(mock_span).to receive(:status=).with(OpenTelemetry::Trace::Status.ok)

      test_job_class.perform_now
    end
  end

  describe "failed job execution" do
    it "instruments job with error metrics and records exception" do
      expect(mock_span).to receive(:set_attribute).with('job.status', 'failed')
      expect(mock_span).to receive(:set_attribute).with('job.duration_ms', anything)
      expect(mock_span).to receive(:set_attribute).with('job.error.class', 'StandardError')
      expect(mock_span).to receive(:set_attribute).with('job.error.message', 'Test error')
      expect(mock_span).to receive(:record_exception).with(instance_of(StandardError))
      expect(mock_span).to receive(:status=).with(instance_of(OpenTelemetry::Trace::Status))

      expect { test_job_class.perform_now(should_fail: true) }.to raise_error(StandardError, "Test error")
    end
  end
end
