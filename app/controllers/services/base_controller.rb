class Services::BaseController < ApplicationController
  before_action :set_service

  private

  def set_service
    @service = current_user.services.find(params[:service_id])
  end
end
