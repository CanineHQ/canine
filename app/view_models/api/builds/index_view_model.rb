# frozen_string_literal: true

module Api
  module Builds
    class IndexViewModel
      LOG_TAIL_LINES = 10

      def initialize(build)
        @build = build
      end

      def as_json
        {
          id: @build.id,
          status: @build.status,
          commit_sha: @build.commit_sha,
          commit_message: @build.commit_message,
          created_at: @build.created_at,
          log_tail: @build.log_outputs.order(:created_at).last(LOG_TAIL_LINES).map { |l| strip_ansi(l.output) }.join("\n")
        }
      end

      private

      def strip_ansi(text)
        text&.gsub(/\e\[[0-9;]*m/, "")
      end
    end
  end
end
