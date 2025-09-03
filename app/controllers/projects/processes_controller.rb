class Projects::ProcessesController < Projects::BaseController
  include LogColorsHelper

  def index
  end

  def create
    kubectl = K8::Kubectl.new(active_connection)
    pod = K8::Stateless::Pod.new(@project)
    kubectl.apply_yaml(pod.to_yaml)
    redirect_to project_processes_path(@project), notice: "One off pod #{pod.name} created"
  end

  def show
    client = K8::Client.new(active_connection)
    @logs = client.get_pod_log(params[:id], @project.name)
    @pod_events = client.get_pod_events(params[:id], @project.name)

    respond_to do |format|
      format.html
      format.turbo_stream { render turbo_stream: turbo_stream.update("logs", partial: "log_outputs/log_chunk", locals: { logs: @logs }) }
    end
  rescue Kubeclient::ResourceNotFoundError
    flash[:alert] = "Pod #{params[:id]} not found"
    redirect_to project_processes_path(@project)
  end

  def destroy
    client = K8::Client.new(active_connection)
    client.delete_pod(params[:id], @project.name)
    redirect_to project_processes_path(@project), notice: "Pod #{params[:id]} terminating..."
  end

  private

    def set_cluster
      @cluster = current_account.clusters.find(params[:cluster_id])
    end
end
