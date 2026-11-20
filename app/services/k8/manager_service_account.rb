# frozen_string_literal: true

# Canine's own identity on a cluster. The kubeconfig a user hands us is only used to create this
# service account; what we keep afterwards is its token, so the connection no longer depends on
# a credential that belongs to (and expires with) the user.
class K8::ManagerServiceAccount < K8::Base
  class TokenNotIssuedError < StandardError; end

  NAME_PREFIX = "canine-manager"
  TOKEN_POLL_ATTEMPTS = 20
  ACCESS_CHECK_ATTEMPTS = 5
  TOKEN_POLL_INTERVAL = 0.5
  TEMPORARY_TOKEN_DURATION = 24.hours

  attr_reader :service_account_name

  # Every import gets a service account of its own. Sharing one name would let deleting one Canine
  # cluster revoke another's access to the same Kubernetes cluster, and re-creating an account under
  # its old name gets the old token back, so a new name is also what makes re-importing rotate it.
  def self.generate_name
    "#{NAME_PREFIX}-#{SecureRandom.hex(4)}"
  end

  # Whether the connection's credentials can do everything Canine needs. Being able to reach the
  # API server says nothing: any authenticated token can do that with no permissions at all.
  def self.full_access?(connection)
    ACCESS_CHECK_ATTEMPTS.times do |attempt|
      sleep(1) if attempt.positive?
      return true if K8::Kubectl.new(connection).call(%w[auth can-i * * --all-namespaces]).to_s.strip == "yes"
    rescue Cli::CommandFailedError
      next
    end
    false
  end

  def initialize(service_account_name)
    @service_account_name = service_account_name
  end

  def namespace
    Clusters::Install::DEFAULT_NAMESPACE
  end

  def token_secret_name
    "#{service_account_name}-token"
  end

  # Creates the service account and returns the attributes Canine connects with from then on.
  def install!
    kubectl.apply_yaml(to_yaml)
    kubectl.call(%W[patch serviceaccount #{service_account_name} -n #{namespace} --type=merge -p #{owner_patch(binding_uid)}])
    credentials(fetch_token)
  end

  # Makes the binding own the service account, so that deleting the binding (see uninstall!) takes the
  # service account, and with it every token, along. Deleting them one by one cannot work: each
  # delete is made with the access the previous one just removed.
  def owner_patch(uid)
    owner = { apiVersion: "rbac.authorization.k8s.io/v1", kind: "ClusterRoleBinding", name: service_account_name, uid: uid }
    { metadata: { ownerReferences: [ owner ] } }.to_json
  end

  # A token for the same service account that the cluster expires on its own. The API server may
  # issue a shorter lifetime than requested.
  def temporary_token(duration: TEMPORARY_TOKEN_DURATION)
    kubectl.call(%W[create token #{service_account_name} -n #{namespace} --duration=#{duration.to_i}s]).to_s.strip
  end

  # A shell script that does what install! does, but from the user's machine with the user's own
  # kubectl login, and reports the resulting credentials to callback_url.
  def registration_script(cluster, callback_url:)
    ERB.new(Rails.root.join("resources/k8/register_cluster.sh.erb").read).result(binding)
  end

  # Revokes Canine's access. The cluster garbage-collects the service account and its token once the
  # binding that owns them is gone.
  def uninstall!
    kubectl.call(%W[delete clusterrolebinding #{service_account_name} --ignore-not-found])
  end

  private

  def binding_uid
    kubectl.call(%W[get clusterrolebinding #{service_account_name} -o jsonpath={.metadata.uid}]).to_s.strip
  end

  def fetch_token
    TOKEN_POLL_ATTEMPTS.times do |attempt|
      sleep(TOKEN_POLL_INTERVAL) if attempt.positive?
      encoded = kubectl.call(%W[get secret #{token_secret_name} -n #{namespace} -o jsonpath={.data.token}]).to_s.strip
      return Base64.decode64(encoded) if encoded.present?
    end
    raise TokenNotIssuedError, "the cluster did not issue a token for the #{service_account_name} service account"
  end

  # Where the cluster is and how to trust it come from the kubeconfig being imported; the identity is
  # ours. Reads the supplied kubeconfig rather than connection.kubeconfig so that a remapped localhost
  # address is never persisted.
  def credentials(token)
    source = connection.cluster.kubeconfig
    context = source["contexts"].find { |ctx| ctx["name"] == source["current-context"] }
    cluster_entry = source["clusters"].find { |cl| cl["name"] == context["context"]["cluster"] }["cluster"]

    {
      server_url: cluster_entry["server"],
      certificate_authority_data: cluster_entry["certificate-authority-data"],
      service_account_token: token
    }.tap do |attributes|
      attributes[:skip_tls_verify] = true if cluster_entry["insecure-skip-tls-verify"]
    end
  end
end
