class Services::BaseController < ApplicationController
  before_action :set_project
  before_action :set_service

  private
  def set_project
    @project = current_user.projects.find(params[:project_id])
  end
  def set_service
    @service = @project.find(params[:service_id])
  end
end
