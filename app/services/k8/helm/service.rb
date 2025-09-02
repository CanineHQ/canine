class K8::Helm::Service
  attr_reader :add_on, :client, :connection, :user, :kubectl

  def self.create_from_add_on(connection)
    add_on = connection.add_on
    if add_on.chart_type == "redis"
      K8::Helm::Redis.new(connection)
    elsif add_on.chart_type == "postgresql"
      K8::Helm::Postgresql.new(connection)
    elsif add_on.chart_type == "clickhouse"
      K8::Helm::Clickhouse.new(connection)
    else
      K8::Helm::Service.new(connection)
    end
  end

  def initialize(connection)
    @connection = connection
    @add_on = connection.add_on
    @client = K8::Client.new(connection)
    @kubectl = K8::Kubectl.new(connection, Cli::RunAndReturnOutput.new)
  end

  def friendly_name
    add_on.chart_definition['friendly_name'] || add_on.chart_definition['name'].titleize
  end

  def restart
    kubectl.call("rollout restart deployment -n #{add_on.name}")
  end

  def get_ingresses
    @client.get_ingresses(namespace: add_on.name)
  end

  def get_endpoints
    @client.get_services(namespace: add_on.name)
  end

  def values_yaml
    helm_client = K8::Helm::Client.connect(connection, Cli::RunAndReturnOutput.new)
    helm_client.get_values_yaml(add_on.name, namespace: add_on.name)
  rescue StandardError => e
    Rails.logger.error("Error getting values.yaml for #{add_on.name}: #{e.message}")
    nil
  end

  def storage_metrics
    pods = client.pods_for_namespace(add_on.name)
    volumes = pods.flat_map do |pod|
      pod.spec.volumes&.select { |volume| volume.respond_to?(:persistentVolumeClaim) && volume.persistentVolumeClaim.claimName }
    end.compact

    pvc_names = volumes.map { |volume| volume.persistentVolumeClaim.claimName }
    pvcs = client.get_persistent_volume_claims(
      namespace: add_on.name,
    ).flatten

    pvcs.map do |pvc|
      pod = pods.find { |p| p.spec.volumes&.any? { |vol| vol.persistentVolumeClaim&.claimName == pvc.metadata.name } }
      mount_path = get_mount_path(pod, pvc.metadata.name) if pod
      usage = mount_path ? get_volume_usage(pod.metadata.name, mount_path) : nil

      {
        name: pvc.metadata.name,
        usage: usage
      }
    end
  end

  def version
    services = K8::Helm::Client.connect(connection, Cli::RunAndReturnOutput.new).ls
    chart = services.find { |service| service['name'] == add_on.name }['chart']
    chart.match(/\d+\.\d+\.\d+/)&.to_s
  end

  private
  def get_mount_path(pod, pvc_name)
    volume = pod.spec.volumes.find { |vol| vol.persistentVolumeClaim&.claimName == pvc_name }
    return nil unless volume

    container = pod.spec.containers.find { |c| c.volumeMounts.any? { |vm| vm.name == volume.name } }
    container&.volumeMounts&.find { |vm| vm.name == volume.name }&.mountPath
  end

  def get_volume_usage(pod_name, mount_path)
    output = kubectl.call("exec #{pod_name} -n #{add_on.name} -- df -h #{mount_path}")
    lines = output.strip.split("\n")
    return nil if lines.size < 2

    usage_line = lines[1].split
    {
      used: usage_line[2],
      available: usage_line[3],
      use_percentage: usage_line[4].to_i
    }
  end

  def get_persistent_volume
    pv = kubectl.call("get pv #{service_name} -o json")
    JSON.parse(pv)
  end

  def exec_df_command
    output = kubectl.call("exec #{service_name} -- df -h /data")
    output.strip
  end
end
