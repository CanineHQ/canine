class Projects::Services::OauthApplicationsController < Projects::Services::BaseController
  def create
    InternalSso::Enable.execute(protectable: @service)
    InternalSso::DeployServiceProxy.execute(service: @service)

    redirect_to project_services_path(@project), notice: "SSO protection enabled for #{@service.name}."
  end

  def destroy
    InternalSso::Disable.execute(protectable: @service)

    redirect_to project_services_path(@project), notice: "SSO protection removed from #{@service.name}."
  end
end
