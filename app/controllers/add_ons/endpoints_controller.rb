class AddOns::EndpointsController < AddOns::BaseController
  before_action :set_add_on

  def edit
    set_dns_record
    endpoints = @service.get_endpoints
    @endpoint = endpoints.find { |endpoint| endpoint.metadata.name == params[:id] }
  end

  def show
    # Aggregate all the services and the ingresses for the services
    ingresses = @service.get_ingresses
  end

  def update
    endpoints = @service.get_endpoints
    @endpoint = endpoints.find { |endpoint| endpoint.metadata.name == params[:id] }
    domains = params[:domains].split(",").map(&:strip)
    @errors = []
    @errors << 'Invalid domain format' unless domains.all? { |domain| valid_domain?(domain) }
    @errors << 'Invalid port' unless @endpoint.spec.ports.map(&:port).include?(params[:port].to_i)
    kubectl = K8::Kubectl.new(active_connection)
    kubectl.apply_yaml(
      K8::AddOns::Ingress.new(
        @add_on,
        @endpoint,
        params[:port].to_i,
        domains,
      ).to_yaml
    )
    if @errors.empty?
      @ingresses = @service.get_ingresses
      render partial: "add_ons/endpoints/endpoint", locals: { add_on: @add_on, endpoint: @endpoint, ingresses: @ingresses }
    else
      set_dns_record
      render "add_ons/endpoints/edit"
    end
  rescue StandardError => e
    @errors << e.message
    set_dns_record
    render "add_ons/endpoints/edit"
  end

  private

  def update_params
    params.require(:ingress).permit(
      :domains,
      :endpoint_url,
    )
  end

  def set_dns_record
    client = K8::Client.new(active_connection)
    hostname = K8::Stateless::Ingress.hostname(client)
    if hostname[:type] == :ip_address && Dns::Utils.private_ip?(hostname[:value])
      hostname = { type: :ip_address, value: Dns::Utils.infer_public_ip(active_connection) }
    end
    @dns_record = hostname
  end

  def valid_domain?(domain)
    # Domain regex pattern
    domain_pattern = /^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$/
    return false if domain.length > 253 # Max domain length
    domain.match?(domain_pattern)
  end
end
