class Projects::Services::BaseController < Projects::BaseController
  before_action :set_project
  before_action :set_service

  private
    def set_service
      @service = @project.services.find(params[:service_id])
    end
end
