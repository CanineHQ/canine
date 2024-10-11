class Projects::LogsController < Projects::BaseController
  include LogColorsHelper
  def index
    @pods = get_pods_for_project(@project)
  end

  def show
    client = K8::Client.new(@project.cluster.kubeconfig)
    @logs = client.get_pod_log(params[:id], @project.name)
  end

  private
    def get_pods_for_project(project)
      # Get all pods for a given namespace
      client = K8::Client.new(project.cluster.kubeconfig).client
      pods = client.get_pods(namespace: project.name)
    end

    def set_cluster
      @cluster = current_user.clusters.find(params[:cluster_id])
    end
end
