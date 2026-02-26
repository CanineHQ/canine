class Clusters::InstallComponents
  extend LightService::Action

  expects :cluster, :kubectl, :connection

  executed do |context|
    cluster = context.cluster
    kubectl = context.kubectl
    connection = context.connection
    namespace = Clusters::Install::DEFAULT_NAMESPACE

    ensure_default_packages(cluster)

    cluster.cluster_packages.where(status: [ :pending, :failed ]).find_each do |package|
      definition = package.definition
      next unless definition

      package.installing!
      cluster.info("Installing #{definition['display_name']}...", color: :yellow)

      begin
        if already_installed?(kubectl, definition, namespace)
          cluster.success("#{definition['display_name']} is already installed")
          package.update!(status: :installed, installed_at: Time.current)
          next
        end

        install_package(cluster, kubectl, connection, package, definition, namespace)
        package.update!(status: :installed, installed_at: Time.current)
        cluster.success("#{definition['display_name']} installed successfully")
      rescue StandardError => e
        package.failed!
        cluster.error("#{definition['display_name']} failed to install: #{e.message}")
      end
    end
  end

  private

  def self.ensure_default_packages(cluster)
    return if cluster.cluster_packages.any?

    ClusterPackage.default_package_names.each do |name|
      cluster.cluster_packages.find_or_create_by!(name: name)
    end
  end

  def self.already_installed?(kubectl, definition, namespace)
    check_ns = definition["check_namespace"] || namespace
    kubectl.("#{definition['check_command']} -n #{check_ns}")
    true
  rescue Cli::CommandFailedError
    false
  end

  def self.install_package(cluster, kubectl, connection, package, definition, namespace)
    case definition["install_type"]
    when "helm"
      install_helm(cluster, connection, package, definition, namespace)
    when "manifest"
      install_manifest(kubectl, definition)
    when "helm_and_manifest"
      install_helm(cluster, connection, package, definition, namespace)
      install_acme_manifest(cluster, kubectl)
    end
  end

  def self.install_helm(cluster, connection, package, definition, namespace)
    runner = Cli::RunAndLog.new(cluster)
    helm = K8::Helm::Client.connect(connection, runner)

    helm.add_repo(definition["repo_name"], definition["repo_url"])
    helm.repo_update(repo_name: definition["repo_name"])

    values = build_values(definition, package.config)

    args = [ definition["chart_name"], definition["chart_url"] ]
    args << definition["chart_version"] if definition["chart_version"].present?

    helm.install(
      *args,
      values: values,
      namespace: namespace,
      create_namespace: true
    )
  end

  def self.install_manifest(kubectl, definition)
    manifest_path = definition["manifest_path"]
    kubectl.apply_yaml(Rails.root.join(manifest_path).read)
  end

  def self.install_acme_manifest(cluster, kubectl)
    cluster.info("Installing ACME issuer...", color: :yellow)
    acme_issuer_yaml = K8::Shared::AcmeIssuer.new(cluster.account.owner.email).to_yaml
    kubectl.apply_yaml(acme_issuer_yaml)
    cluster.success("ACME issuer installed")
  end

  def self.build_values(definition, user_config)
    values = (definition["values"] || {}).deep_dup
    return values if user_config.blank?

    values.extend(DotSettable)
    user_config.each do |key, value|
      values.dotset(key, value)
    end
    values
  end
end
