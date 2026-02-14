class K8::Shared::GatewayManager < K8::Base
  GATEWAY_NAME = "canine-gateway".freeze
  GATEWAY_NAMESPACE = Clusters::Install::DEFAULT_NAMESPACE

  def ensure_certificate_ref(service)
    gateway = get_gateway
    return unless gateway

    https_listener = gateway.dig("spec", "listeners")&.find { |l| l["name"] == "https" }
    return unless https_listener

    cert_name = "#{service.name}-tls"
    namespace = service.project.namespace

    cert_refs = https_listener["tls"]["certificateRefs"] || []
    already_exists = cert_refs.any? { |ref| ref["name"] == cert_name && ref["namespace"] == namespace }
    return if already_exists

    cert_refs << { "kind" => "Secret", "name" => cert_name, "namespace" => namespace }
    https_listener["tls"]["certificateRefs"] = cert_refs

    kubectl.apply_yaml(gateway.to_yaml)
  end

  def remove_certificate_ref(service)
    gateway = get_gateway
    return unless gateway

    https_listener = gateway.dig("spec", "listeners")&.find { |l| l["name"] == "https" }
    return unless https_listener

    cert_name = "#{service.name}-tls"
    namespace = service.project.namespace

    cert_refs = https_listener["tls"]["certificateRefs"] || []
    cert_refs.reject! { |ref| ref["name"] == cert_name && ref["namespace"] == namespace }
    https_listener["tls"]["certificateRefs"] = cert_refs

    kubectl.apply_yaml(gateway.to_yaml)
  end

  def hostname
    @hostname ||= begin
      result = kubectl.call(
        "get service -n #{GATEWAY_NAMESPACE} -l gateway.envoyproxy.io/owning-gateway-name=#{GATEWAY_NAME} -o json"
      )
      services = JSON.parse(result)["items"]
      svc = services&.first
      raise "Envoy Gateway proxy service not found" unless svc

      ingress = svc.dig("status", "loadBalancer", "ingress")&.first
      raise "LoadBalancer not ready" unless ingress

      if ingress["ip"]
        { value: ingress["ip"], type: :ip_address }
      else
        { value: ingress["hostname"], type: :hostname }
      end
    end
  rescue StandardError => e
    Rails.logger.error("Error getting gateway hostname: #{e.message}")
    nil
  end

  private

  def get_gateway
    result = kubectl.call("get gateway #{GATEWAY_NAME} -n #{GATEWAY_NAMESPACE} -o yaml")
    YAML.safe_load(result)
  rescue StandardError => e
    Rails.logger.error("Error getting gateway: #{e.message}")
    nil
  end
end
