class AddOns::EndpointsController < AddOns::BaseController
  before_action :set_add_on

  def edit
    @ip_address = Networks::CheckDns.infer_public_ip_from_cluster(active_connection)
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
      render "add_ons/endpoints/edit"
    end
  rescue StandardError => e
    @errors << e.message
    render "add_ons/endpoints/edit"
  end

  private

  def update_params
    params.require(:ingress).permit(
      :domains,
      :endpoint_url,
    )
  end

  def valid_domain?(domain)
    # Domain regex pattern
    domain_pattern = /^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$/
    return false if domain.length > 253 # Max domain length
    domain.match?(domain_pattern)
  end
end
