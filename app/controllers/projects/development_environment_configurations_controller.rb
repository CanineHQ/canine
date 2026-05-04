class Projects::DevelopmentEnvironmentConfigurationsController < Projects::BaseController
  before_action :set_configuration, only: %i[update destroy]

  def create
    @configuration = @project.build_development_environment_configuration(configuration_params)
    result = DevelopmentEnvironmentConfigurations::Save.execute(development_environment_configuration: @configuration, user: current_user)

    if result.success?
      redirect_to edit_project_path(@project, anchor: "development-environment"), notice: "Development environment configuration saved."
    else
      prepare_edit_page
      render "projects/edit", status: :unprocessable_entity
    end
  end

  def update
    @configuration.assign_attributes(configuration_params)
    result = DevelopmentEnvironmentConfigurations::Save.execute(development_environment_configuration: @configuration, user: current_user)

    if result.success?
      redirect_to edit_project_path(@project, anchor: "development-environment"), notice: "Development environment configuration updated."
    else
      prepare_edit_page
      render "projects/edit", status: :unprocessable_entity
    end
  end

  def destroy
    @configuration.destroy
    redirect_to edit_project_path(@project, anchor: "development-environment"), notice: "Development environment configuration removed."
  end

  private

  def set_configuration
    @configuration = @project.development_environment_configuration
    return if @configuration

    redirect_to edit_project_path(@project), alert: "Development environment configuration not found."
  end

  def configuration_params
    DevelopmentEnvironmentConfiguration.permit_params(
      params.require(:development_environment_configuration)
    )
  end

  def prepare_edit_page
    @selectable_providers = current_account.providers.where(provider: @project.provider.provider)
    @clusters = current_account.clusters.running.where.not(id: @project.cluster_id)
    @development_environment_clusters = current_account.clusters.running.order(:name)
    @git_providers = current_user.providers.where(provider: @project.provider.provider)
  end
end
