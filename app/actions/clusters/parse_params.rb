class Clusters::ParseParams
  extend LightService::Action
  expects :account, :params
  promises :cluster

  executed do |context|
    parsed = parse_params(context.params)
    context.cluster = context.account.clusters.new(parsed)
  end

  def self.parse_params(params)
    # Handle kubeconfig from YAML editor
    if params[:cluster][:kubeconfig_yaml_format] == "true" && params[:cluster][:kubeconfig].present?
      params[:cluster][:kubeconfig] = YAML.safe_load(params[:cluster][:kubeconfig])
    elsif params[:cluster][:cluster_type] == "k3s"
      ip_address = params[:cluster][:ip_address]
      kubeconfig_output = params[:cluster][:k3s_kubeconfig_output]
      if ip_address.blank? || kubeconfig_output.blank?
        message = "IP address and kubeconfig output are required for K3s clusters"
        context.fail_and_return!(message)
      end

      begin
        data = YAML.safe_load(kubeconfig_output)
        data["clusters"][0]["cluster"]["server"] = "https://#{ip_address}:6443"
      rescue StandardError => e
        message = "Invalid kubeconfig output"
        context.fail_and_return!(message)
      end
      params[:cluster][:kubeconfig] = data
    elsif params[:cluster][:cluster_type] == "local_k3s"
      kubeconfig_output = params[:cluster][:local_k3s_kubeconfig_output]
      if kubeconfig_output.blank?
        message = "Kubeconfig output is required for local K3s clusters"
        context.fail_and_return!(message)
      end

      begin
        params[:cluster][:kubeconfig] = YAML.safe_load(kubeconfig_output)
      rescue StandardError => e
        message = "Invalid kubeconfig output"
        context.fail_and_return!(message)
      end
    elsif (kubeconfig_file = params[:cluster][:kubeconfig_file]).present?
      yaml_content = kubeconfig_file.read

      params[:cluster][:kubeconfig] = YAML.safe_load(yaml_content)
    end

    if Rails.configuration.remap_localhost.present?
      params[:cluster][:kubeconfig] = remap_localhost(
        params[:cluster][:kubeconfig],
        Rails.configuration.remap_localhost
      )
    end

    params.require(:cluster).permit(:name, :cluster_type, :skip_tls_verify, kubeconfig: {})
  end

  def self.remap_localhost(kubeconfig, remap_host)
    kubeconfig.dup.tap do |remapped|
      remapped['clusters'].each do |cluster|
        uri = URI.parse(cluster['cluster']['server'])
        if is_localhost?(uri.host)
          uri.host = remap_host
          cluster['cluster']['server'] = uri.to_s
        end
      end
    end
  end

  def self.is_localhost?(server)
    server == "127.0.0.1" || server == "localhost"
  end
end