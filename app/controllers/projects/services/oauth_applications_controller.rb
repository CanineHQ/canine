class Projects::Services::OauthApplicationsController < Projects::Services::BaseController
  def create
    InternalSSO::Enable.execute(protectable: @service)
    InternalSSO::DeployServiceProxy.execute(service: @service)

    render_networking_tab
  end

  def destroy
    InternalSSO::Disable.execute(protectable: @service)

    render_networking_tab
  end

  private

  def render_networking_tab
    @service.reload
    render turbo_stream: turbo_stream.replace(
      "service_#{@service.id}",
      partial: "projects/services/show",
      locals: { service: @service, tab: "networking" }
    )
  end
end
