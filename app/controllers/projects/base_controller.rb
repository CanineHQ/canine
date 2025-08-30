class Projects::BaseController < ApplicationController
  include ProjectsHelper
  before_action :set_project

  def active_connection
    @_active_connection ||= K8::Connection.new(@project.cluster, current_user)
  end

  private
  def set_project
    @project = current_account.projects.find(params[:project_id])
  end
end
