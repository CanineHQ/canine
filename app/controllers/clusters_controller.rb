class ClustersController < ApplicationController
  before_action :set_cluster, only: [
    :show, :edit, :update, :destroy,
    :test_connection, :download_kubeconfig, :logs, :download_yaml,
  ]
  skip_before_action :authenticate_user!, only: [:new]

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

  def test_connection
    client = K8::Client.new(@cluster.kubeconfig)
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
          yaml_content = K8::Kubectl.new(@cluster.kubeconfig).call("get #{resource} -n #{project.name} -o yaml")
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

    # Uncomment to authorize with Pundit
    # authorize @cluster

    respond_to do |format|
      if @cluster.save
        # Kick off cluster job
        InstallClusterJob.perform_later(@cluster)
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
    if params[:cluster][:kubeconfig].present?
      kubeconfig_file = params[:cluster][:kubeconfig]
      yaml_content = kubeconfig_file.read

      params[:cluster][:kubeconfig] = YAML.safe_load(yaml_content)
    end

    params.require(:cluster).permit(:name, kubeconfig: {})
  end
end
