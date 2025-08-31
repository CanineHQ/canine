class AddOns::ProcessesController < AddOns::BaseController
  include LogColorsHelper

  def index;end

  def show
    client = K8::Client.new(active_connection)
    @logs = client.get_pod_log(params[:id], @add_on.name)
    @pod_events = client.get_pod_events(params[:id], @add_on.name)
  rescue Kubeclient::ResourceNotFoundError
    flash[:alert] = "Pod #{params[:id]} not found"
    redirect_to add_on_processes_path(@add_on)
  end
end
