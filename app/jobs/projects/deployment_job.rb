require "base64"
require "json"

class Projects::DeploymentJob < ApplicationJob
  DEPLOYABLE_RESOURCES = %w[ConfigMap Deployment CronJob Service Ingress Pv Pvc]
  class DeploymentFailure < StandardError; end

  def perform(deployment, user)
    @logger = deployment
    @marked_resources = []
    project = deployment.project
    connection = K8::Connection.new(project, user)
    kubectl = create_kubectl(deployment, connection)

    # Create namespace
    apply_namespace(project, kubectl)

    # Upload container registry secrets
    upload_registry_secrets(kubectl, deployment)
    apply_config_map(project, kubectl)

    deploy_volumes(project, kubectl)
    predeploy(project, kubectl, connection)
    # For each of the projects services
    deploy_services(project, kubectl)

    sweep_unused_resources(project, kubectl)

    # Kill all one off containers
    kill_one_off_containers(project, kubectl)

    postdeploy(project, kubectl, connection)
    deployment.completed!
    project.deployed!
  rescue StandardError => e
    @logger.error("Deployment failed: #{e.message}")
    puts e.full_message
    deployment.failed!
  end

  private

  def deploy_volumes(project, kubectl)
    project.volumes.each do |volume|
      begin
        apply_pv(volume, kubectl)
        apply_pvc(volume, kubectl)
        volume.deployed!
      rescue StandardError => e
        @logger.error("Volume deployment failed: #{e.message}")
        volume.failed!
        raise e
      end
    end
  end

  def _run_command(command, kubectl, project, type, connection)
    @logger.info("Running command: `#{command}`...", color: :yellow)
    command = K8::Stateless::Command.new(project, type, command).connect(connection)
    command_yaml = command.to_yaml
    command.delete_if_exists!
    kubectl.apply_yaml(command_yaml)
    command.wait_for_completion
    # Get logs f
  end

  def predeploy(project, kubectl, connection)
    return unless project.predeploy_command.present?

    _run_command(project.predeploy_command, kubectl, project, 'predeploy', connection)
  end

  def postdeploy(project, kubectl, connection)
    return unless project.postdeploy_command.present?

    _run_command(project.postdeploy_command, kubectl, project, 'postdeploy', connection)
  end

  def create_kubectl(deployment, connection)
    runner = Cli::RunAndLog.new(deployment)
    K8::Kubectl.new(connection, runner)
  end

  def deploy_services(project, kubectl)
    project.services.each do |service|
      deploy_service(service, kubectl)
    end
  end

  def deploy_service(service, kubectl)
    if service.background_service?
      apply_deployment(service, kubectl)
      restart_deployment(service, kubectl)
    elsif service.cron_job?
      apply_cron_job(service, kubectl)
    elsif service.web_service?
      apply_deployment(service, kubectl)
      apply_service(service, kubectl)
      if service.domains.any? && service.allow_public_networking?
        apply_ingress(service, kubectl)
      end
      restart_deployment(service, kubectl)
    end
    service.healthy!
  end

  def kill_one_off_containers(project, kubectl)
    kubectl.call("-n #{project.name} delete pods -l oneoff=true")
  end

  def apply_namespace(project, kubectl)
    @logger.info("Creating namespace: #{project.name}", color: :yellow)
    namespace_yaml = K8::Namespace.new(project).to_yaml
    kubectl.apply_yaml(namespace_yaml)
  end

  def sweep_unused_resources(project, user)
    # Check deployments that need to be deleted
    # Exclude Persistent Volumes
    resources_to_sweep = DEPLOYABLE_RESOURCES.reject { |r| [ 'Pv' ].include?(r) }
    kubectl = K8::Kubectl.new(K8::Connection.new(project, user))

    resources_to_sweep.each do |resource_type|
      results = YAML.safe_load(kubectl.call("get #{resource_type.downcase} -o yaml -n #{project.name}"))
      results['items'].each do |resource|
        if @marked_resources.select do |r|
          r.is_a?(K8::Stateless.const_get(resource_type))
        end.none? do |applied_resource|
          applied_resource.name == resource['metadata']['name']
        end && resource.dig('metadata', 'labels', 'caninemanaged') == 'true'
          @logger.info("Deleting #{resource_type}: #{resource['metadata']['name']}", color: :yellow)
          kubectl.call("delete #{resource_type.downcase} #{resource['metadata']['name']} -n #{project.name}")
        end
      end
    end
  end

  DEPLOYABLE_RESOURCES.each do |resource_type|
    define_method(:"apply_#{resource_type.underscore}") do |service, kubectl|
      @logger.info("Creating #{resource_type}: #{service.name}", color: :yellow)
      resource = K8::Stateless.const_get(resource_type).new(service)
      resource_yaml = resource.to_yaml
      kubectl.apply_yaml(resource_yaml)
      @marked_resources << resource
    end
  end

  def restart_deployment(service, kubectl)
    @logger.info("Restarting deployment: #{service.name}", color: :yellow)
    kubectl.call("-n #{service.project.name} rollout restart deployment/#{service.name}")
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
end
