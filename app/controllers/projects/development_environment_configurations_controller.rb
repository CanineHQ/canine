class Projects::DevelopmentEnvironmentConfigurationsController < Projects::BaseController
  before_action :set_configuration, only: %i[update destroy]

  def create
    @configuration = @project.build_development_environment_configuration(configuration_params)
    @configuration.cluster = current_account.clusters.find(dev_env_params[:cluster_id])
    result = DevelopmentEnvironmentConfigurations::Save.execute(development_environment_configuration: @configuration)

    if result.success?
      redirect_to edit_project_path(@project, anchor: "development-environment"), notice: "Development environment configuration saved."
    else
      prepare_edit_page
      render "projects/edit", status: :unprocessable_entity
    end
  end

  def update
    @configuration.assign_attributes(configuration_params)
    @configuration.cluster = current_account.clusters.find(dev_env_params[:cluster_id])
    result = DevelopmentEnvironmentConfigurations::Save.execute(development_environment_configuration: @configuration)

    if result.success?
      redirect_to edit_project_path(@project, anchor: "development-environment"), notice: "Development environment configuration updated."
    else
      prepare_edit_page
      render "projects/edit", status: :unprocessable_entity
    end
  end

  def destroy
    if @configuration.destroy
      redirect_to edit_project_path(@project, anchor: "development-environment"), notice: "Development environment configuration removed."
    else
      redirect_to edit_project_path(@project, anchor: "development-environment"), alert: "Failed to remove development environment configuration."
    end
  end

  private

  def set_configuration
    @configuration = @project.development_environment_configuration
    return if @configuration

    redirect_to edit_project_path(@project), alert: "Development environment configuration not found."
  end

  def dev_env_params
    params.require(:development_environment_configuration)
  end

  def configuration_params
    DevelopmentEnvironmentConfiguration.permit_params(dev_env_params)
  end

  def prepare_edit_page
    @selectable_providers = current_account.providers.where(provider: @project.provider.provider)
    @clusters = current_account.clusters.running.where.not(id: @project.cluster_id)
    @development_environment_clusters = current_account.clusters.running.order(:name)
  end
end
