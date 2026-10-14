class Projects::ErrorTrackingConfigurationsController < Projects::BaseController
  def create
    @project.error_tracking_configuration || @project.create_error_tracking_configuration!
    redirect_to project_error_issues_path(@project), notice: "Error tracking enabled."
  end

  def destroy
    @project.error_tracking_configuration&.destroy
    redirect_to project_error_issues_path(@project), notice: "Error tracking disabled."
  end

  def regenerate_key
    ErrorTrackingConfiguration.find_by!(project: @project).regenerate_public_key!
    redirect_to project_error_issues_path(@project), notice: "DSN regenerated. Update your SDK configuration with the new DSN."
  end
end
