class Local::OnboardingController < ApplicationController
  layout "homepage"
  skip_before_action :authenticate_user!

  def index
  end

  def create
    result = Portainer::Onboarding::Create.call(params)

    if result.success?
      sign_in(result.user)
      redirect_to root_path
    else
      redirect_to local_onboarding_index_path, alert: result.message
    end
  end

  def verify_url
    url = params[:url]

    begin
      response = HTTParty.get(url, timeout: 5, verify: false)

      if response.success?
        render json: { success: true }
      else
        render json: { success: false, message: "Server returned status #{response.code}" }
      end
    rescue Net::ReadTimeout
      render json: { success: false, message: "Connection timeout - server took too long to respond" }
    rescue SocketError, Errno::ECONNREFUSED
      render json: { success: false, message: "Unable to connect - please check the URL" }
    rescue StandardError => e
      render json: { success: false, message: "Error: #{e.message}" }
    end
  end
end
