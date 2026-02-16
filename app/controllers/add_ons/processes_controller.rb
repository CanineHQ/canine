class AddOns::ProcessesController < AddOns::BaseController
  include LogColorsHelper

  def index;end

  def show
    client = K8::Client.new(active_connection)
    @pod_events = client.get_pod_events(params[:id], @add_on.name)
    @logs = client.get_pod_log(params[:id], @add_on.name)
  rescue Kubeclient::HttpError => e
    @logs = ""
    @error = e.to_s
  rescue Kubeclient::ResourceNotFoundError
    flash[:alert] = "Pod #{params[:id]} not found"
    redirect_to add_on_processes_path(@add_on)
  end

  def shell
    @pod_name = params[:id]
    @namespace = @add_on.name
    @container = params[:container]
    @shell_token = ShellToken.generate_for(
      user: current_user,
      cluster: @add_on.cluster,
      pod_name: @pod_name,
      namespace: @namespace,
      container: @container
    )
  end
end
