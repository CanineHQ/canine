module K8
  class Client
    attr_reader :client

    delegate(
      :get_persistent_volume_claims,
      :get_services,
      :get_pods,
      :get_pod_log,
      :delete_pod,
      :get_endpoints,
      :get_namespaces,
      :delete_namespace,
      :get_events,
      to: :client
    )

    def self.from_project(project)
      new(project.cluster.kubeconfig)
    end

    def self.from_cluster(cluster)
      new(cluster.kubeconfig)
    end

    def initialize(kubeconfig)
      @_kubeconfig = kubeconfig
      @kubeconfig = kubeconfig.is_a?(String) ? JSON.parse(kubeconfig) : kubeconfig
      @client = build_client
    end

    def get_ingresses(namespace:)
      result = K8::Kubectl.new(@_kubeconfig).call("get ingresses -n #{namespace} -o json")
      JSON.parse(result, object_class: OpenStruct).items
    end

    def can_connect?
      @client.discover
      true
    rescue StandardError => e
      puts "Connection failed: #{e.message}"
      false
    end

    def pods_for_namespace(namespace)
      @client.get_pods(namespace:)
    end

    def pods_for_service(service_name, namespace)
      pods_for_namespace(namespace).select do |pod|
        pod.metadata.name.start_with?(service_name)
      end
    end

    def server
      cluster_name = @kubeconfig["contexts"].find { |ctx| ctx["name"] == kubecontext }["context"]["cluster"]
      cluster_info = @kubeconfig["clusters"].find { |cl| cl["name"] == cluster_name }["cluster"]
      cluster_info["server"]
    end

    def version
      result = K8::Kubectl.new(@_kubeconfig).call("version -o yaml")
      YAML.safe_load(result)
    end

    def kubecontext
      @kubeconfig["current-context"]
    end

    def get_pod_events(pod_name, namespace)
      get_events(
        namespace: namespace,
        field_selector: "involvedObject.name=#{pod_name},involvedObject.kind=Pod"
      )
    end

    private

    def load_kubeconfig(kubeconfig_string)
      YAML.safe_load(kubeconfig_string)
    rescue Psych::SyntaxError => e
      raise "Invalid YAML in kubeconfig: #{e.message}"
    end

    def build_client
      cluster_name = @kubeconfig["contexts"].find { |ctx| ctx["name"] == kubecontext }["context"]["cluster"]
      user_name = @kubeconfig["contexts"].find { |ctx| ctx["name"] == kubecontext }["context"]["user"]

      cluster_info = @kubeconfig["clusters"].find { |cl| cl["name"] == cluster_name }["cluster"]
      user_info = @kubeconfig["users"].find { |usr| usr["name"] == user_name }["user"]

      Kubeclient::Client.new(
        server,
        "v1",
        ssl_options: ssl_options(user_info, cluster_info),
        auth_options: auth_options(user_info)
      )
    end

    def ssl_options(user_info, cluster_info)
      _ssl_options = {}
      if user_info["client-certificate-data"] && user_info["client-key-data"]

        begin
          _ssl_options[:client_key] = OpenSSL::PKey::RSA.new(Base64.decode64(user_info["client-key-data"]))
        rescue OpenSSL::PKey::RSAError
          _ssl_options[:client_key] = OpenSSL::PKey::EC.new(Base64.decode64(user_info["client-key-data"]))
        end
        _ssl_options[:client_cert] =
          OpenSSL::X509::Certificate.new(Base64.decode64(user_info["client-certificate-data"]))
        _ssl_options[:verify_ssl] = OpenSSL::SSL::VERIFY_NONE
      end
      # if cluster_info['certificate-authority-data']
      #  ssl_options[:ca_file] = write_temp_file(Base64.decode64(cluster_info['certificate-authority-data']))
      # end
      _ssl_options
    end

    def auth_options(user_info)
      auth_options = {}
      if user_info["token"]
        auth_options[:bearer_token] = user_info["token"]
      end
      auth_options
    end

    def write_temp_file(content)
      file = Tempfile.new
      file.write(content)
      file.close
      file.path
    end
  end
end
