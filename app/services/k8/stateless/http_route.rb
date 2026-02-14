class K8::Stateless::HttpRoute < K8::Base
  attr_accessor :service, :project, :domains, :cluster

  def initialize(service)
    @service = service
    @project = service.project
    @cluster = @project.cluster
  end

  def name
    "#{@service.name}-httproute"
  end

  def certificate_status
    return nil unless @service.domains.any?
    return nil unless @service.allow_public_networking?

    kubectl.call("get certificate #{certificate_name} -n #{@project.namespace} -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}'") == "True"
  end

  def certificate_name
    "#{@service.name}-tls"
  end

  def hostname
    @hostname ||= gateway_manager.hostname
  rescue StandardError => e
    Rails.logger.error("Error getting gateway hostname: #{e.message}")
    nil
  end

  private

  def gateway_manager
    @gateway_manager ||= K8::Shared::GatewayManager.new.connect(@connection)
  end
end
