class Projects::ProcessesController < Projects::BaseController
  include LogColorsHelper

  def index
    @pods = get_pods_for_project(@project)
  end

  def create
    kubectl = K8::Kubectl.from_project(@project)
    pod = K8::Stateless::Pod.new(@project)
    kubectl.apply_yaml(pod.to_yaml)
    redirect_to project_processes_path(@project), notice: "One off pod #{pod.name} created"
  end

  def show
    client = K8::Client.new(@project.cluster.kubeconfig)
    @logs = client.get_pod_log(params[:id], @project.name)
  end

  def destroy
    client = K8::Client.from_project(@project)
    client.delete_pod(params[:id], @project.name)
    redirect_to project_processes_path(@project), notice: "Pod #{params[:id]} terminating..."
  end

  private
    def get_pods_for_project(project)
      # Get all pods for a given namespace
      client = K8::Client.from_project(project).client
      pods = client.get_pods(namespace: project.name)
    end

    def set_cluster
      @cluster = current_account.clusters.find(params[:cluster_id])
    end
end
