# Creates a cluster that has no credentials yet. They arrive when the user runs the registration
# command against the cluster, which is how clusters whose kubeconfig only works on the user's
# machine (EKS, GKE, AKS and other exec-plugin logins) get connected.
class Clusters::CreateForRegistration
  extend LightService::Organizer

  def self.call(params, account_user)
    cluster = account_user.account.clusters.new(
      name: params.dig(:cluster, :name),
      cluster_type: :k8s,
      options: { "registration_pending" => true, "service_account_name" => K8::ManagerServiceAccount.generate_name }
    )
    Clusters::ParseParams.build_packages(cluster, params)
    with(cluster:, user: account_user.user).reduce(Clusters::Save)
  end
end
