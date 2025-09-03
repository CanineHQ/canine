class ClustersController < ApplicationController
  before_action :set_cluster, only: [
    :show, :edit, :update, :destroy,
    :test_connection, :download_kubeconfig, :logs, :download_yaml,
    :retry_install, :transfer_ownership
  ]

  # GET /clusters
  def index
    sortable_column = params[:sort] || "created_at"
    @pagy, @clusters = pagy(current_account.clusters.order(sortable_column => "asc"))

    # Uncomment to authorize with Pundit
    # authorize @clusters
  end

  # GET /clusters/1 or /clusters/1.json
  def show
  end

  # GET /clusters/new
  def new
    @cluster = Cluster.new

    # Uncomment to authorize with Pundit
    # authorize @cluster
  end

  # GET /clusters/1/edit
  def edit
  end

  def logs
  end

  def check_k3s_ip_address
    # Check if the IP address is reachable at port 6443
    ip_address = params[:ip_address]
    port = 6443
    timeout = 5  # seconds

    begin
      Timeout.timeout(timeout) do
        TCPSocket.new(ip_address, port).close
      end
      render json: { success: true }
    rescue Errno::ECONNREFUSED
      render json: { success: false, error: "Connection refused" }, status: :unprocessable_entity
    rescue Errno::EHOSTUNREACH
      render json: { success: false, error: "Host unreachable" }, status: :unprocessable_entity
    rescue Timeout::Error
      render json: { success: false, error: "Connection timed out" }, status: :unprocessable_entity
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end
  end

  def retry_install
    Clusters::InstallJob.perform_later(@cluster, current_user)
    redirect_to @cluster, notice: "Retrying installation for cluster..."
  end

  def test_connection
    client = K8::Client.new(K8::Connection.new(@cluster, current_user))
    if client.can_connect?
      render turbo_stream: turbo_stream.replace("test_connection_frame", partial: "clusters/connection_success")
    else
      render turbo_stream: turbo_stream.replace("test_connection_frame", partial: "clusters/connection_failed")
    end
  end

  def export(cluster, namespace, yaml_content, zip)
    parsed = YAML.safe_load(yaml_content)

    parsed['items'].each do |item|
      name = item['metadata']['name']
      zip.put_next_entry("#{cluster}/#{namespace}/#{name}.yaml")
      zip.write(item.to_yaml)
    end
  end

  def download_yaml
    require 'zip'

    stringio = Zip::OutputStream.write_buffer do |zio|
      @cluster.projects.each do |project|
        # Create a directory for each project
        # Export services, deployments, ingress and cron jobs from a kubernetes namespace
        %w[services deployments ingress cronjobs].each do |resource|
          yaml_content = K8::Kubectl.new(
            K8::Connection.new(@cluster, current_user)
          ).call("get #{resource} -n #{project.name} -o yaml")
          export(@cluster.name, project.name, yaml_content, zio)
        end
      end
    end
    stringio.rewind

    # Send the zip file to the user
    send_data(stringio.read,
      filename: "#{@cluster.name}.zip",
      type: "application/zip"
    )
  end

  def download_kubeconfig
    send_data @cluster.kubeconfig.to_yaml, filename: "#{@cluster.name}-kubeconfig.yml", type: "application/yaml"
  end

  # POST /clusters or /clusters.json
  def create
    @cluster = current_account.clusters.new(cluster_params)
    result = Clusters::Create.call(@cluster, current_user)

    # Uncomment to authorize with Pundit
    # authorize @cluster

    respond_to do |format|
      if result.success?
        # Kick off cluster job
        Clusters::InstallJob.perform_later(@cluster, current_user)
        format.html { redirect_to @cluster, notice: "Cluster was successfully created." }
        format.json { render :show, status: :created, location: @cluster }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @cluster.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /clusters/1 or /clusters/1.json
  def update
    respond_to do |format|
      if @cluster.update(cluster_params)
        format.html { redirect_to @cluster, notice: "Cluster was successfully updated." }
        format.json { render :show, status: :ok, location: @cluster }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @cluster.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /clusters/1 or /clusters/1.json
  def destroy
    @cluster.destroy!
    respond_to do |format|
      format.html { redirect_to clusters_url, status: :see_other, notice: "Cluster was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def edit
  end

  def destroy
    Clusters::DestroyJob.perform_later(@cluster, current_user)
    respond_to do |format|
      format.html { redirect_to clusters_url, status: :see_other, notice: "Cluster is being deleted... It may take a few minutes to complete." }
      format.json { head :no_content }
    end
  end

  def transfer_ownership
    @cluster.update(account_id: params[:cluster][:account_id])
    redirect_to cluster_url(@cluster), notice: "Cluster ownership transferred successfully"
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_cluster
    @cluster = current_account.clusters.find(params[:id])

    # Uncomment to authorize with Pundit
    # authorize @cluster
  rescue ActiveRecord::RecordNotFound
    redirect_to clusters_path
  end

  # Only allow a list of trusted parameters through.
  def cluster_params
    # Handle kubeconfig from YAML editor
    if params[:cluster][:kubeconfig_yaml_format] == "true" && params[:cluster][:kubeconfig].present?
      params[:cluster][:kubeconfig] = YAML.safe_load(params[:cluster][:kubeconfig])
    elsif params[:cluster][:cluster_type] == "k3s"
      ip_address = params[:cluster][:ip_address]
      kubeconfig_output = params[:cluster][:kubeconfig_output]
      if ip_address.blank? || kubeconfig_output.blank?
        message = "IP address and kubeconfig output are required for K3s clusters"
        flash[:error] = message
        raise message
      end

      begin
        data = YAML.safe_load(kubeconfig_output)
        data["clusters"][0]["cluster"]["server"] = "https://#{ip_address}:6443"
      rescue StandardError => e
        message = "Invalid kubeconfig output"
        flash[:error] = message
        raise message
      end
      params[:cluster][:kubeconfig] = data
    elsif (kubeconfig_file = params[:cluster][:kubeconfig_file]).present?
      yaml_content = kubeconfig_file.read

      params[:cluster][:kubeconfig] = YAML.safe_load(yaml_content)
    end

    params.require(:cluster).permit(:name, :cluster_type, kubeconfig: {})
  end
end
