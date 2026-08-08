class Projects::WorkbenchesController < Projects::BaseController
  before_action :require_development_environment

  MAX_UPLOAD_SIZE = 10.megabytes
  UPLOAD_DIR = "/tmp/uploads"

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

  def destroy_session
    session = ShellToken.where(user: current_user).connected.find_by(id: params[:session_id])
    session&.destroy
    broadcast_session_update

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("shell_sessions_list", partial: "projects/workbenches/session_list"),
          turbo_stream.replace("session_count", partial: "projects/workbenches/session_count")
        ]
      end
      format.html { redirect_to project_workbench_path(@project), notice: "Session terminated." }
    end
  end

  def upload
    file = params[:file]

    if file.blank?
      return render json: { error: "No file provided" }, status: :unprocessable_entity
    end

    if file.size > MAX_UPLOAD_SIZE
      return render json: { error: "File too large (max #{MAX_UPLOAD_SIZE / 1.megabyte}MB)" }, status: :unprocessable_entity
    end

    pod_name = params[:pod_name]
    namespace = @project.namespace
    filename = sanitize_filename(file.original_filename)
    remote_path = "#{UPLOAD_DIR}/#{filename}"

    kubectl = K8::Kubectl.new(active_connection)
    container_flag = [ "-c", @project.name ]

    kubectl.call([ "exec", "-n", namespace, pod_name ] + container_flag + [ "--", "mkdir", "-p", UPLOAD_DIR ])
    kubectl.call([ "cp", file.tempfile.path, "#{namespace}/#{pod_name}:#{remote_path}" ] + container_flag)

    render json: { path: remote_path }
  rescue Cli::CommandFailedError => e
    render json: { error: "Upload failed: #{e.message}" }, status: :unprocessable_entity
  end

  private

  def broadcast_session_update
    Turbo::StreamsChannel.broadcast_replace_to(
      [ current_user, :shell_sessions ],
      target: "shell_sessions_list",
      partial: "projects/workbenches/session_list",
      locals: { current_user: current_user }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      [ current_user, :shell_sessions ],
      target: "session_count",
      partial: "projects/workbenches/session_count",
      locals: { current_user: current_user }
    )
  end

  def require_development_environment
    redirect_to project_path(@project), alert: "Workbench is only available for development environments." unless @project.development_environment?
  end

  def sanitize_filename(name)
    # Strip path components, replace unsafe chars, prepend timestamp to avoid collisions
    base = File.basename(name).gsub(/[^\w.\-]/, "_")
    "#{Time.current.to_i}_#{base}"
  end

  def fetch_pods
    client = K8::Client.new(active_connection)
    client.get_pods(namespace: @project.namespace)
  rescue StandardError
    []
  end
end
