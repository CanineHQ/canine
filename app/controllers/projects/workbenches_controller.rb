class Projects::WorkbenchesController < Projects::BaseController
  def show
    @pods = running_pods
    @pod = @pods.first

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

  def running_pods
    client = K8::Client.new(active_connection)
    client.get_pods(namespace: @project.namespace).select { |pod| pod.status.phase == "Running" }
  rescue StandardError
    []
  end
end
