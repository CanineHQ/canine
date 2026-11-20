class Clusters::CompleteRegistration
  extend LightService::Action
  expects :cluster, :server_url, :certificate_authority_data, :service_account_token

  executed do |context|
    cluster = context.cluster
    server_url = context.server_url.to_s.strip
    # The script sends the token as the cluster stores it, base64 encoded.
    token = Base64.decode64(context.service_account_token.to_s)
    context.fail_and_return!("the cluster address is not a valid URL") unless valid_url?(server_url)
    context.fail_and_return!("no service account token was sent") if token.blank?

    # The lock makes a registration link single use even when two callbacks arrive together.
    cluster.with_lock do
      context.fail_and_return!("this cluster has already been connected") unless cluster.registration_pending?

      cluster.assign_attributes(
        server_url:,
        certificate_authority_data: context.certificate_authority_data.presence,
        service_account_token: token
      )
      cluster.skip_tls_verify = true if Rails.configuration.remap_localhost.present? && K8::Kubeconfig.is_localhost?(server_url)
      connection = K8::Connection.new(cluster, nil)

      unless Clusters::ValidateKubeConfig.can_connect?(connection)
        context.fail_and_return!("#{server_url} is not reachable from Canine with the new service account")
      end
      unless K8::ManagerServiceAccount.full_access?(connection)
        context.fail_and_return!("the service account does not have cluster-admin access on #{server_url}")
      end

      cluster.options = cluster.options.except("registration_pending")
      context.fail_and_return!(cluster.errors.full_messages.join(", ")) unless cluster.save
    end
  end

  def self.valid_url?(url)
    URI.parse(url).is_a?(URI::HTTP)
  rescue URI::InvalidURIError
    false
  end
end
