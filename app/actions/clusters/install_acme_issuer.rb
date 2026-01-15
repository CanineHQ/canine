class Clusters::InstallAcmeIssuer
  extend LightService::Action

  REPO_NAME = "jetstack".freeze
  REPO_URL = "https://charts.jetstack.io".freeze
  CHART_NAME = "cert-manager".freeze
  CHART_URL = "jetstack/cert-manager".freeze
  CHART_VERSION = "v1.15.3".freeze

  CERT_MANAGER_VALUES = {
    crds: {
      enabled: true
    }
  }.freeze

  expects :cluster, :kubectl, :connection

  executed do |context|
    cluster = context.cluster
    kubectl = context.kubectl
    connection = context.connection
    namespace = Clusters::Install::DEFAULT_NAMESPACE

    cluster.info("Checking if acme issuer is already installed", color: :yellow)

    begin
      kubectl.("get clusterissuer letsencrypt -n #{namespace}")
      cluster.success("Acme issuer is already installed")
    rescue Cli::CommandFailedError => e
      cluster.info("Acme issuer not detected, installing...", color: :yellow)
      cluster.info("Installing cert-manager...", color: :yellow)

      begin
        runner = Cli::RunAndLog.new(cluster)
        helm = K8::Helm::Client.connect(connection, runner)

        helm.add_repo(REPO_NAME, REPO_URL)
        helm.repo_update(repo_name: REPO_NAME)
        helm.install(
          CHART_NAME,
          CHART_URL,
          CHART_VERSION,
          values: CERT_MANAGER_VALUES,
          namespace: namespace,
          create_namespace: true
        )

        cluster.success("Cert-manager installed successfully")
      rescue StandardError => e
        cluster.failed!
        cluster.error("Cert-manager failed to install")
        context.fail_and_return!("Helm install failed: #{e.message}")
      end

      cluster.info("Installing acme issuer...", color: :yellow)
      acme_issuer_yaml = K8::Shared::AcmeIssuer.new(cluster.account.owner.email).to_yaml
      kubectl.apply_yaml(acme_issuer_yaml)
      cluster.success("Acme issuer installed")
    end
  rescue StandardError => e
    cluster.failed!
    cluster.error("Acme issuer failed to install")
  end
end
