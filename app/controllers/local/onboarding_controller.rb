class Local::OnboardingController < ApplicationController
  layout "homepage"
  skip_before_action :authenticate_user!
  before_action :redirect_if_onboarded

  def index
    @in_cluster = K8::Connection.in_cluster?
    if @in_cluster
      @cluster_nodes, @cluster_version = fetch_in_cluster_info
    end
  end

  def account_select
    redirect_to new_user_session_path unless Rails.application.config.account_sign_in_only

    @accounts = Account.all.includes(:stack_manager)
  end

  def create
    result = case params[:onboarding_method]
    when "portainer"
      Portainer::Onboarding::Create.call(params)
    when "rancher"
      Rancher::Onboarding::Create.call(params)
    when "normal"
      Onboarding::Create.call(params)
    else
      redirect_to local_onboarding_index_path, alert: "Invalid onboarding method"
      return
    end

    if result.success?
      sign_in(result.user)
      session[:account_id] = result.account.id
      redirect_to root_path
    else
      redirect_to local_onboarding_index_path, alert: result.message
    end
  end

  private

  def redirect_if_onboarded
    redirect_to new_user_session_path if User.exists?
  end

  def fetch_in_cluster_info
    cluster = Cluster.new(options: { "in_cluster" => true })
    connection = K8::Connection.new(cluster, nil)
    kubectl = K8::Kubectl.new(connection)

    # Use kubectl get nodes (doesn't require metrics-server)
    raw = YAML.safe_load(kubectl.call(%w[get nodes -o yaml]))
    nodes = (raw["items"] || []).map do |item|
      allocatable = item.dig("status", "allocatable") || {}
      K8::Metrics::Api::Node.new(
        name: item.dig("metadata", "name"),
        cpu_cores: 0,
        total_cpu: K8::Metrics::Api::Node.compute_to_integer(allocatable["cpu"] || "0"),
        used_memory: 0,
        total_memory: K8::Metrics::Api::Node.memory_to_integer(allocatable["memory"] || "0")
      )
    end

    version = K8::Client.new(connection).version["serverVersion"]["gitVersion"]
    [ nodes, version ]
  rescue StandardError => e
    Rails.logger.error("Failed to fetch in-cluster info: #{e.message}")
    [ [], nil ]
  end
end
