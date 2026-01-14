class Clusters::InstallNginxIngress
  extend LightService::Action

  REPO_NAME = "ingress-nginx".freeze
  REPO_URL = "https://kubernetes.github.io/ingress-nginx".freeze
  CHART_NAME = "ingress-nginx".freeze
  CHART_URL = "ingress-nginx/ingress-nginx".freeze

  NGINX_VALUES = {
    controller: {
      config: {
        "use-forwarded-headers" => "true",
        "proxy-real-ip-cidr" => "0.0.0.0/0",
        "enable-underscores-in-headers" => "true",
        "proxy-pass-headers" => "*",
        "proxy-body-size" => "0",
        "proxy-buffer-size" => "16k",
        "proxy-buffers-number" => "8",
        "proxy-busy-buffers-size" => "32k",
        "proxy-read-timeout" => "3600",
        "proxy-send-timeout" => "3600",
        "h2-backend" => "true",
        "hsts" => "true",
        "hsts-max-age" => "63072000",
        "hsts-include-subdomains" => "true",
        "hsts-preload" => "true",
        "enable-gzip" => "true",
        "gzip-types" => "text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript"
      }
    }
  }.freeze

  expects :cluster, :kubectl, :connection

  executed do |context|
    cluster = context.cluster
    kubectl = context.kubectl
    connection = context.connection
    namespace = Clusters::Install::DEFAULT_NAMESPACE

    cluster.info("Checking if Nginx ingress controller is already installed...", color: :yellow)

    begin
      kubectl.("get deployment ingress-nginx-controller -n #{namespace}")
      cluster.success("Nginx ingress controller is already installed")
    rescue Cli::CommandFailedError => e
      cluster.info("Nginx ingress controller not detected, installing...", color: :yellow)

      begin
        runner = Cli::RunAndLog.new(cluster)
        helm = K8::Helm::Client.connect(connection, runner)

        helm.add_repo(REPO_NAME, REPO_URL)
        helm.repo_update(repo_name: REPO_NAME)
        helm.install(
          CHART_NAME,
          CHART_URL,
          values: NGINX_VALUES,
          namespace: namespace
        )

        cluster.success("Nginx ingress controller installed successfully")
      rescue StandardError => e
        cluster.failed!
        cluster.error("Nginx ingress controller failed to install")
        context.fail_and_return!("Helm install failed: #{e.message}")
      end
    end
  end
end
