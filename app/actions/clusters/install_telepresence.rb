class Clusters::InstallTelepresence
  extend LightService::Action

  REPO_NAME = "datawire".freeze
  REPO_URL = "https://getambassador.io".freeze
  CHART_NAME = "traffic-manager".freeze
  CHART_URL = "datawire/telepresence".freeze

  expects :cluster, :kubectl, :connection

  executed do |context|
    cluster = context.cluster
    kubectl = context.kubectl
    connection = context.connection
    namespace = Clusters::Install::DEFAULT_NAMESPACE

    cluster.info("Checking if Telepresence is already installed...", color: :yellow)

    begin
      kubectl.("get deployment traffic-manager -n #{namespace}")
      cluster.success("Telepresence already installed")
    rescue Cli::CommandFailedError => e
      cluster.info("Telepresence not detected, installing...", color: :yellow)

      begin
        runner = Cli::RunAndLog.new(cluster)
        helm = K8::Helm::Client.connect(connection, runner)

        helm.add_repo(REPO_NAME, REPO_URL)
        helm.repo_update(repo_name: REPO_NAME)
        helm.install(
          CHART_NAME,
          CHART_URL,
          namespace: namespace
        )

        cluster.success("Telepresence installed successfully")
      rescue StandardError => e
        cluster.failed!
        cluster.error("Telepresence failed to install")
        context.fail_and_return!("Helm install failed: #{e.message}")
      end
    end
  end
end
