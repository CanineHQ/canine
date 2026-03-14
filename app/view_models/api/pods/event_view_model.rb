# frozen_string_literal: true

module Api
  module Pods
    class EventViewModel
      def initialize(event)
        @event = event
      end

      def as_json
        {
          type: @event.type,
          reason: @event.reason,
          message: @event.message,
          first_seen: @event.firstTimestamp&.iso8601,
          last_seen: @event.lastTimestamp&.iso8601,
          count: @event.count
        }
      end
    end
  end
end
