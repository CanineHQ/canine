module InboundWebhooks
  class ApplicationController < ActionController::API
    private

    def payload
      @payload ||= request.form_data? ? request.request_parameters.to_json : request.raw_post
    end
  end
end
