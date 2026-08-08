class ShellSessionsController < ApplicationController
  MAX_UPLOAD_SIZE = 10.megabytes
  UPLOAD_DIR = "/tmp/uploads"

  def destroy
    session = ShellToken.where(user: current_user).connected.find(params[:id])
    session.destroy

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("shell_session_#{params[:id]}"),
          turbo_stream.replace("session_count", partial: "projects/workbenches/session_count")
        ]
      end
      format.html { redirect_back fallback_location: root_path, notice: "Session terminated." }
    end
  end

  def upload
    shell_token = ShellToken.where(user: current_user).connected.find(params[:id])
    file = params[:file]

    if file.blank?
      return render json: { error: "No file provided" }, status: :unprocessable_entity
    end

    if file.size > MAX_UPLOAD_SIZE
      return render json: { error: "File too large (max #{MAX_UPLOAD_SIZE / 1.megabyte}MB)" }, status: :unprocessable_entity
    end

    filename = sanitize_filename(file.original_filename)
    remote_path = "#{UPLOAD_DIR}/#{filename}"

    connection = K8::Connection.new(shell_token.cluster, current_user)
    kubectl = K8::Kubectl.new(connection)
    container_flag = shell_token.container.present? ? [ "-c", shell_token.container ] : []

    kubectl.call([ "exec", "-n", shell_token.namespace, shell_token.pod_name ] + container_flag + [ "--", "mkdir", "-p", UPLOAD_DIR ])
    kubectl.call([ "cp", file.tempfile.path, "#{shell_token.namespace}/#{shell_token.pod_name}:#{remote_path}" ] + container_flag)

    render json: { path: remote_path }
  rescue Cli::CommandFailedError => e
    render json: { error: "Upload failed: #{e.message}" }, status: :unprocessable_entity
  end

  private

  def sanitize_filename(name)
    base = File.basename(name).gsub(/[^\w.\-]/, "_")
    "#{Time.current.to_i}_#{base}"
  end
end
