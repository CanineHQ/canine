# The two halves of connecting a cluster with a command instead of a kubeconfig upload: the script
# the user pipes into their shell, and the callback that script makes. Neither has a session; the
# signed, expiring token in the URL is what identifies the cluster being registered.
class ClusterRegistrationsController < ActionController::Base
  skip_forgery_protection
  before_action :set_cluster

  def show
    script = K8::ManagerServiceAccount.new(@cluster.service_account_name).registration_script(@cluster, callback_url: cluster_registration_url(params[:token]))
    render plain: script, content_type: "text/x-shellscript"
  end

  def create
    result = Clusters::CompleteRegistration.execute(
      cluster: @cluster,
      server_url: params[:server_url],
      certificate_authority_data: params[:certificate_authority_data],
      service_account_token: params[:service_account_token]
    )

    if result.success?
      Clusters::InstallJob.perform_later(@cluster, @cluster.account.owner)
      render plain: "Connected. Canine is now setting up #{@cluster.name}."
    else
      render plain: "Canine could not connect the cluster: #{result.message}", status: :unprocessable_entity
    end
  end

  private

  def set_cluster
    @cluster = Cluster.find_by_token_for(:registration, params[:token])
    render plain: "This registration link has expired or has already been used.", status: :not_found unless @cluster
  end
end
