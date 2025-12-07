class Projects::DeploymentJob < ApplicationJob
  DEPLOYABLE_RESOURCES = %w[ConfigMap Secrets Deployment CronJob Service Ingress Pv Pvc]
  def perform(deployment, user)
    @logger = deployment
    project = deployment.project
    connection = K8::Connection.new(project, user, allow_anonymous: true)
    @kubectl = K8::Kubectl.new(connection)

    chart_builder = K8::Helm::ChartBuilder.new(
      project.name,
      deployment,
    ).connect(connection)
    chart_builder.register_before_install do |yaml_content|
      deployment.add_manifest(yaml_content)
    end

    apply_namespace(project) if project.managed_namespace?
    upload_registry_secrets(@kubectl, deployment)
    chart_builder << apply_config_map(project)
    chart_builder << apply_secrets(project)

    deploy_volumes(project, chart_builder)
    predeploy(project, connection)
    deploy_services(project, chart_builder)
    chart_builder.install_chart(project.name)
    kill_one_off_containers(project)
    postdeploy(project, connection)

    mark_services_healthy(project)
    deployment.completed!
    project.deployed!
  #rescue StandardError => e
  #  @logger.error("Deployment failed: #{e.message}")
  #  puts e.full_message
  #  deployment.failed!
  end

  def apply_namespace(project)
    namespace_yaml = K8::Namespace.new(project).to_yaml
    @kubectl.apply_yaml(namespace_yaml)
  end

  def upload_registry_secrets(kubectl, deployment)
    project = deployment.project
    @logger.info("Creating registry secret for #{project.container_image_reference}", color: :yellow)
    provider = project.build_provider
    result = Providers::GenerateConfigJson.execute(
      provider:,
    )
    raise StandardError, result.message if result.failure?

    secret_yaml = K8::Secrets::RegistrySecret.new(project, result.docker_config_json).to_yaml
    kubectl.apply_yaml(secret_yaml)
  end

  DEPLOYABLE_RESOURCES.each do |resource_type|
    define_method(:"apply_#{resource_type.underscore}") do |service|
      K8::Stateless.const_get(resource_type).new(service)
    end
  end

  def deploy_volumes(project, chart_builder)
    project.volumes.each do |volume|
      begin
        chart_builder << apply_pv(volume)
        chart_builder << apply_pvc(volume)
        volume.deployed!
      rescue StandardError => e
        volume.failed!
        raise e
      end
    end
  end

  def deploy_services(project, chart_builder)
    project.services.each do |service|
      deploy_service(service, chart_builder)
    end
  end

  def deploy_service(service, chart_builder)
    if service.background_service?
      chart_builder << apply_deployment(service)
    elsif service.cron_job?
      chart_builder << apply_cron_job(service)
    elsif service.web_service?
      chart_builder << apply_deployment(service)
      chart_builder << apply_service(service)
      if service.domains.any? && service.allow_public_networking?
        chart_builder << apply_ingress(service)
      end
    end
  end

  def mark_services_healthy(project)
    project.services.each(&:healthy!)
  end

  def kill_one_off_containers(project)
    @kubectl.call("-n #{project.namespace} delete pods -l oneoff=true")
  end

  def predeploy(project, connection)
    return unless project.predeploy_command.present?

    run_command(project.predeploy_command, project, "predeploy", connection)
  end

  def postdeploy(project, connection)
    return unless project.postdeploy_command.present?

    run_command(project.postdeploy_command, project, "postdeploy", connection)
  end

  def run_command(command, project, type, connection)
    command_job = K8::Stateless::Command.new(project, type, command).connect(connection)
    command_job.delete_if_exists!
    @kubectl.apply_yaml(command_job.to_yaml)
    command_job.wait_for_completion
  end
end
