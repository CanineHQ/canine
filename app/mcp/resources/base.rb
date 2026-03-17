# frozen_string_literal: true

module Resources
  class Base
    class << self
      def uri_pattern
        raise NotImplementedError, "#{name} must define uri_pattern"
      end

      def matches?(uri)
        uri_pattern === uri
      end

      def call(uri:, user:, account_users:)
        raise NotImplementedError, "#{name} must implement call"
      end

      private

      def json(uri, data)
        [ { uri: uri, mimeType: "application/json", text: data.to_json } ]
      end

      def not_found(uri, message)
        [ { uri: uri, mimeType: "text/plain", text: message } ]
      end
    end
  end
end
