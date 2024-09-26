module InboundWebhooks
  class ApplicationController < ActionController::API
    private

    # Returns the payload for the webhook as a String
    #
    # Some services use multipart/form-data to encapsulate their JSON payload
    # For multipart/form-data we will let Rails parse and then dump the params as JSON
    def payload
      @payload ||= request.form_data? ? request.request_parameters.to_json : request.raw_post
    end
  end
end
