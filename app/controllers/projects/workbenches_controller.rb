class Projects::WorkbenchesController < Projects::BaseController
  before_action :require_development_environment

  def show
    @pods = running_pods
    @pod = @pods.find { |pod| pod.spec.initContainers&.any? { |c| c.name == "rover" } }

    if @pod
      @pod_name = @pod.metadata.name
      @namespace = @project.namespace
      @shell_token = ShellToken.generate_for(
        user: current_user,
        cluster: @project.cluster,
        pod_name: @pod_name,
        namespace: @namespace,
        container: "rover"
      )
    end
  end

  private

  def require_development_environment
    redirect_to project_path(@project), alert: "Workbench is only available for development environments." unless @project.development_environment?
  end

  def running_pods
    client = K8::Client.new(active_connection)
    client.get_pods(namespace: @project.namespace).select { |pod| pod.status.phase == "Running" }
  rescue StandardError
    []
  end
end
