# frozen_string_literal: true

module Api
  module Pods
    class LogViewModel
      def initialize(pod, logs:, events:, service_name: nil)
        @pod = pod
        @logs = logs
        @events = events
        @service_name = service_name
      end

      def as_json
        data = {
          pod_name: @pod.metadata.name,
          status: @pod.status.phase,
          container_status: @pod.status.containerStatuses&.first&.state&.to_h,
          logs: @logs,
          events: @events
        }
        data[:service_name] = @service_name if @service_name
        data
      end
    end
  end
end
