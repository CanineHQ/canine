# frozen_string_literal: true

class Projects::EnvironmentVariablesController < Projects::BaseController
  before_action :set_project

  def index
    @environment_variables = @project.environment_variables.order(:name)
  end

  def show
    @environment_variable = @project.environment_variables.find(params[:id])
    render json: { value: @environment_variable.value }
  end

  def download
    env_content = @project.environment_variables.order(:name).map { |ev| "#{ev.name}=#{ev.value}" }.join("\n")
    send_data env_content,
              filename: "#{@project.name.parameterize}.env",
              type: 'text/plain',
              disposition: 'attachment'
  end

  def create
    result = EnvironmentVariables::Update.call(
      project: @project,
      params:,
      current_user:
    )
    if result.success?
      @project.updated!

      if @project.current_deployment.present?
        Projects::DeploymentJob.perform_later(@project.current_deployment)
        @project.events.create(user: current_user, eventable: @project.last_build, event_action: :update)
        redirect_to project_environment_variables_path(@project),
                    notice: "Restarting services with new environment variables."
      else
        redirect_to project_environment_variables_path(@project),
                    notice: "Environment variables will be applied on the next deployment."
      end
    else
      redirect_to project_environment_variables_path(@project), alert: "Failed to update environment variables: #{result.message}"
    end
  end

  def destroy
    @environment_variable = @project.environment_variables.find(params[:id])
    @environment_variable.destroy
    if @project.current_deployment.present?
      Projects::DeploymentJob.perform_later(@project.current_deployment)
    end
    render turbo_stream: turbo_stream.remove("environment_variable_#{@environment_variable.id}")
  end
end
