class Projects::DevelopmentEnvironmentConfigurationsController < Projects::BaseController
  before_action :set_configuration, only: %i[update destroy]

  def create
    @configuration = @development_environment_configuration = @project.build_development_environment_configuration(configuration_params)
    result = DevelopmentEnvironmentConfigurations::Save.execute(development_environment_configuration: @configuration, user: current_user)

    if result.success?
      respond_with_configuration("Development environment configuration saved.")
    else
      respond_with_configuration(status: :unprocessable_entity)
    end
  end

  def update
    @development_environment_configuration = @configuration
    @configuration.assign_attributes(configuration_params)
    result = DevelopmentEnvironmentConfigurations::Save.execute(development_environment_configuration: @configuration, user: current_user)

    if result.success?
      respond_with_configuration("Development environment configuration updated.")
    else
      respond_with_configuration(status: :unprocessable_entity)
    end
  end

  def destroy
    @configuration.destroy
    @development_environment_configuration = nil
    respond_with_configuration("Development environment configuration removed.")
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

  def respond_with_configuration(notice_message = nil, status: :ok)
    respond_to do |format|
      format.html do
        if turbo_frame_request?
          prepare_edit_page
          render partial: "projects/development_environment_configurations/section",
                 locals: {
                   project: @project,
                   clusters: @development_environment_clusters,
                   git_providers: @git_providers,
                   configuration: @development_environment_configuration,
                   notice_message: notice_message
                 },
                 status: status
        elsif status == :unprocessable_entity
          prepare_edit_page
          render "projects/edit", status: status
        else
          redirect_to edit_project_path(@project), notice: notice_message
        end
      end
    end
  end

  def prepare_edit_page
    @selectable_providers = current_account.providers.where(provider: @project.provider.provider)
    @clusters = current_account.clusters.running.where.not(id: @project.cluster_id)
    @development_environment_clusters = current_account.clusters.running.order(:name)
    @git_providers = current_user.providers.where(provider: @project.provider.provider)
  end
end
