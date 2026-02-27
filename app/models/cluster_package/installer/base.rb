class ClusterPackage::Installer::Base
  attr_reader :package

  delegate :definition, to: :package

  def initialize(package)
    @package = package
  end

  def install!(kubectl)
    case definition["install_type"]
    when "helm"
      install_helm(kubectl)
    when "manifest"
      install_manifest(kubectl)
    when "helm_and_manifest"
      install_helm(kubectl)
      install_manifest(kubectl)
    end
  end

  def uninstall!(kubectl)
    namespace = Clusters::Install::DEFAULT_NAMESPACE

    case definition["install_type"]
    when "helm", "helm_and_manifest"
      helm = build_helm(kubectl)
      helm.uninstall(definition["chart_name"], namespace: namespace)
    when "manifest"
      manifest_path = definition["manifest_path"]
      kubectl.("delete -f #{Rails.root.join(manifest_path)} --ignore-not-found")
    end
  end

  def installed?(kubectl)
    namespace = Clusters::Install::DEFAULT_NAMESPACE
    check_ns = definition["check_namespace"] || namespace
    kubectl.("#{definition['check_command']} -n #{check_ns}")
    true
  rescue Cli::CommandFailedError
    false
  end

  private

  def install_helm(kubectl)
    namespace = Clusters::Install::DEFAULT_NAMESPACE
    helm = build_helm(kubectl)

    helm.add_repo(definition["repo_name"], definition["repo_url"])
    helm.repo_update(repo_name: definition["repo_name"])

    values = build_values

    args = [ definition["chart_name"], definition["chart_url"] ]
    args << definition["chart_version"] if definition["chart_version"].present?

    helm.install(
      *args,
      values: values,
      namespace: namespace,
      create_namespace: true
    )
  end

  def install_manifest(kubectl)
    manifest_path = definition["manifest_path"]
    kubectl.apply_yaml(Rails.root.join(manifest_path).read)
  end

  def build_helm(kubectl)
    K8::Helm::Client.connect(kubectl.connection, kubectl.runner)
  end

  def build_values
    values = (definition["values"] || {}).deep_dup
    return values if package.config.blank?

    values.extend(DotSettable)
    package.config.each do |key, value|
      values.dotset(key, value)
    end
    values
  end
end
