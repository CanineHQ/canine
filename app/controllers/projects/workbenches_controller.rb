class Projects::WorkbenchesController < Projects::BaseController
  before_action :require_development_environment

  def show
    all_pods = fetch_pods
    @pods = all_pods.select { |pod| pod.status.phase == "Running" }
    @pod = @pods.first

    if @pod
      @pod_name = @pod.metadata.name
      @namespace = @project.namespace
      @shell_token = ShellToken.generate_for(
        user: current_user,
        cluster: @project.cluster,
        pod_name: @pod_name,
        namespace: @namespace,
        container: @project.name
      )
    else
      pending_pod = all_pods.find { |pod| pod.status.phase == "Pending" }
      @workbench_status = Workbench::Status.new(@project, pending_pod: pending_pod)
    end
  end

  private

  def require_development_environment
    redirect_to project_path(@project), alert: "Workbench is only available for development environments." unless @project.development_environment?
  end

  def fetch_pods
    client = K8::Client.new(active_connection)
    client.get_pods(namespace: @project.namespace)
  rescue StandardError
    []
  end
end
