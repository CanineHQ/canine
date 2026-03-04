class Clusters::InstallTraefik
  extend LightService::Action

  REPO_NAME = "traefik".freeze
  REPO_URL = "https://traefik.github.io/charts".freeze
  CHART_NAME = "traefik".freeze
  CHART_URL = "traefik/traefik".freeze

  TRAEFIK_VALUES = {
    providers: {
      kubernetesGateway: {
        enabled: true
      },
      kubernetesIngress: {
        enabled: true
      }
    },
    gateway: {
      enabled: false
    }
  }.freeze

  expects :cluster, :kubectl, :connection

  executed do |context|
    cluster = context.cluster
    kubectl = context.kubectl
    connection = context.connection
    namespace = Clusters::Install::DEFAULT_NAMESPACE

    cluster.info("Checking if Traefik is already installed...", color: :yellow)

    begin
      kubectl.call("get deployment traefik -n #{namespace}")
      cluster.success("Traefik is already installed")
    rescue Cli::CommandFailedError
      cluster.info("Traefik not detected, installing...", color: :yellow)

      begin
        runner = Cli::RunAndLog.new(cluster)
        helm = K8::Helm::Client.connect(connection, runner)

        helm.add_repo(REPO_NAME, REPO_URL)
        helm.repo_update(repo_name: REPO_NAME)
        helm.install(
          CHART_NAME,
          CHART_URL,
          values: TRAEFIK_VALUES,
          namespace: namespace
        )

        cluster.success("Traefik installed successfully")
      rescue StandardError => e
        cluster.failed!
        cluster.error("Traefik failed to install")
        context.fail_and_return!("Helm install failed: #{e.message}")
      end
    end
  end
end
