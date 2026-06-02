class K8::Connection
  attr_reader :clusterable, :user, :allow_anonymous
  def initialize(clusterable, user, allow_anonymous: false)
    @clusterable = clusterable
    @user = user
    @allow_anonymous = allow_anonymous
  end

  def cluster
    klass = clusterable.class.name
    if klass == "Cluster"
      clusterable
    elsif klass == "Project"
      clusterable.cluster
    elsif klass == "AddOn"
      clusterable.cluster
    else
      raise "`clusterable` is not a Cluster, Project, or AddOn"
    end
  end

  def kubeconfig
    config = if cluster.in_cluster?
      build_in_cluster_kubeconfig
    elsif cluster.kubeconfig.present?
      cluster.kubeconfig
    else
      raise StandardError.new("No stack manager found") if stack_manager.blank?
      stack = stack_manager.stack.connect(user, allow_anonymous:)
      stack.fetch_kubeconfig(cluster)
    end

    if Rails.configuration.remap_localhost.present?
      remap_host = Rails.configuration.remap_localhost
      config.dup.tap do |remapped|
        remapped['clusters']&.each do |c|
          c['cluster']['server'] = K8::Kubeconfig.remap_localhost(c['cluster']['server'], remap_host)
        end
      end
    else
      config
    end
  end

  def stack_manager
    cluster.account.stack_manager
  end

  SA_TOKEN_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/token"
  SA_CA_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"

  def self.in_cluster?
    ENV["KUBERNETES_SERVICE_HOST"].present? && File.exist?(SA_TOKEN_PATH)
  end

  %i[add_on project].each do |method_name|
    define_method method_name do
      class_name = method_name.to_s.classify
      raise "`clusterable` is not a #{class_name}" unless clusterable.is_a?(class_name.constantize)
      clusterable
    end
  end

  private

  def build_in_cluster_kubeconfig
    host = ENV.fetch("KUBERNETES_SERVICE_HOST")
    port = ENV.fetch("KUBERNETES_SERVICE_PORT", "443")
    token = File.read(SA_TOKEN_PATH)
    ca_data = Base64.strict_encode64(File.read(SA_CA_PATH))

    {
      "apiVersion" => "v1",
      "kind" => "Config",
      "current-context" => "in-cluster",
      "clusters" => [ {
        "name" => "in-cluster",
        "cluster" => {
          "server" => "https://#{host}:#{port}",
          "certificate-authority-data" => ca_data
        }
      } ],
      "contexts" => [ {
        "name" => "in-cluster",
        "context" => {
          "cluster" => "in-cluster",
          "user" => "service-account"
        }
      } ],
      "users" => [ {
        "name" => "service-account",
        "user" => {
          "token" => token
        }
      } ]
    }
  end
end
