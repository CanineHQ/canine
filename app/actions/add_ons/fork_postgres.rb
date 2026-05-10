class AddOns::ForkPostgres
  extend LightService::Action

  expects :source_add_on, :target_add_on, :user

  executed do |context|
    source = context.source_add_on
    target = context.target_add_on
    user = context.user

    unless source.chart_url == "bitnami/postgresql"
      context.fail_and_return!("Forking is only supported for PostgreSQL add-ons")
    end

    source_connection = K8::Connection.new(source, user, allow_anonymous: true)
    target_connection = K8::Connection.new(target, user, allow_anonymous: true)

    # Step 1: Install the target add-on
    target.info("Installing #{target.name}...")
    AddOns::InstallHelmChart.execute(connection: target_connection)

    # Step 2: Wait for target pods to be ready
    target.info("Waiting for #{target.name} to be ready...")
    wait_for_ready(target_connection, target)

    # Step 3: Dump data from source pod directly to target via cluster-internal DNS
    source_pod = find_primary_pod(source_connection, source)
    source_password = fetch_postgres_password(source_connection)
    target_password = fetch_postgres_password(target_connection)

    target_service = K8::Helm::Postgresql.new(target_connection)
    target_host = "#{target_service.service_name}.#{target.namespace}.svc.cluster.local"

    target.info("Dumping data from #{source.name} (#{source_pod}) -> #{target.name} (#{target_host})...")

    # Run pg_dumpall on source pod, pipe into psql connecting to target's cluster-internal service
    inner_cmd = "PGPASSWORD=#{source_password} pg_dumpall -U postgres --clean | PGPASSWORD=#{target_password} psql -h #{target_host} -U postgres"
    command = "kubectl exec #{source_pod} -n #{source.namespace} -- bash -c '#{inner_cmd}'"

    K8::Kubeconfig.with_kube_config(
      source_connection.kubeconfig,
      skip_tls_verify: source_connection.cluster.skip_tls_verify
    ) do |kubeconfig_file|
      runner = Cli::RunAndLog.new(target, log_command: true)
      runner.call(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
    end

    target.info("Data fork complete!")
  end

  def self.fetch_postgres_password(connection)
    K8::Helm::Postgresql.new(connection).send(:password)
  end

  def self.find_primary_pod(connection, add_on)
    client = K8::Client.new(connection)
    service_name = add_on.name.ends_with?("postgresql") ? add_on.name : "#{add_on.name}-postgresql"
    pods = client.pods_for_namespace(add_on.namespace)
    pod = pods.find { |p| p.metadata.name.start_with?(service_name) }
    raise "No primary pod found for #{service_name} in namespace #{add_on.namespace}" unless pod

    pod.metadata.name
  end

  def self.wait_for_ready(connection, add_on)
    kubectl = K8::Kubectl.new(connection, Cli::RunAndReturnOutput.new)
    60.times do
      result = kubectl.call("get pods -n #{add_on.namespace} -o jsonpath='{.items[*].status.conditions[?(@.type==\"Ready\")].status}'")
      statuses = result.strip.delete("'").split
      if statuses.present? && statuses.all? { |s| s == "True" }
        add_on.info("All pods are ready")
        return
      end
      sleep 5
    end
    raise "Timed out waiting for pods to be ready in #{add_on.namespace}"
  end
end
