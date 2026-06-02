class Local::OnboardingController < ApplicationController
  layout "homepage"
  skip_before_action :authenticate_user!

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

  def fetch_in_cluster_info
    # Build a temporary in-cluster connection without a persisted cluster
    cluster = Cluster.new(options: { "in_cluster" => true })
    connection = K8::Connection.new(cluster, nil)
    nodes = K8::Metrics::Api::Node.ls(connection, with_namespaces: false)
    version = K8::Client.new(connection).version["serverVersion"]["gitVersion"]
    [ nodes, version ]
  rescue StandardError => e
    Rails.logger.error("Failed to fetch in-cluster info: #{e.message}")
    [ [], nil ]
  end
end
