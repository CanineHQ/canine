class Projects::DevelopmentEnvironmentConfigurationsController < ApplicationController
  before_action :set_project
  before_action :set_development_environment_configuration, only: %i[show edit update destroy]

  def show
    # Show SSH connection details
  end

  def new
    @development_environment_configuration = @project.build_development_environment_configuration(
      ssh_username: "developer",
      ssh_port: 2222,
      branch_name: @project.branch,
      enabled: true
    )
  end

  def edit
  end

  def create
    @development_environment_configuration = @project.build_development_environment_configuration(
      development_environment_configuration_params
    )

    if @development_environment_configuration.save
      redirect_to project_path(@project), notice: "Development environment configuration was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @development_environment_configuration.update(development_environment_configuration_params)
      redirect_to project_path(@project), notice: "Development environment configuration was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @development_environment_configuration.destroy
    redirect_to project_path(@project), notice: "Development environment configuration was successfully deleted."
  end

  private

  def set_project
    @project = current_account.projects.find_by!(slug: params[:project_slug])
  end

  def set_development_environment_configuration
    @development_environment_configuration = @project.development_environment_configuration
    redirect_to new_project_development_environment_configuration_path(@project), alert: "No development environment configuration found." unless @development_environment_configuration
  end

  def development_environment_configuration_params
    params.require(:development_environment_configuration).permit(
      :dockerfile_path,
      :application_path,
      :anthropic_api_key,
      :branch_name,
      :ssh_username,
      :ssh_password,
      :ssh_port,
      :enabled
    )
  end
end
