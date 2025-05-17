class Async::K8::ClusterIpViewModel < Async::BaseViewModel
  expects :service_id

  def service
    service ||= current_user.services.find(params[:service_id])
  end

  def initial_render
    "<div class='loading loading-spinner loading-sm'></div>"
  end

  def async_render
    ip = K8::Stateless::Ingress.new(service).ip_address
    if is_private_ip?(ip)
      cluster = service.project.cluster
      ip = infer_public_ip_from_cluster(cluster)
    end
    "<pre class='cursor-pointer' data-controller='clipboard' data-clipboard-text='#{ip}'>#{ip}</pre>"
  end

  def infer_public_ip_from_cluster(cluster)
    # The ingress is reporting a private IP address, so we need to guess the public IP address
    # based on the cluster's domain name
    server_name = K8::Client.new(cluster.kubeconfig).server
    # Parse the hostname from the server, with ruby's URI.parse
    hostname = URI.parse(server_name).hostname
    # If hostname is just an ip address, then we can return it
    if ip?(hostname)
      hostname
    else
      # Otherwise, we need to use Resolv to get the public IP address
      Resolv.getaddress(hostname)
    end
  end

  def ip?(ip)
    ip.match?(/\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\z/)
  end

  def is_private_ip?(ip)
    ip.starts_with?("10.") || ip.starts_with?("172.") || ip.starts_with?("192.")
  end
end
