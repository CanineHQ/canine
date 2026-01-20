class Deployments::BaseDeploymentService
  class DeploymentFailure < StandardError; end

  DEPLOYABLE_RESOURCES = %w[ConfigMap Secrets Deployment CronJob Service Ingress Pv Pvc].freeze

  def initialize(deployment, user)
    @deployment = deployment
    @user = user
    @project = deployment.project
    @logger = deployment
  end

  def deploy
    raise NotImplementedError, "Subclasses must implement #deploy"
  end

  private

  def setup_connection
    @connection = K8::Connection.new(@project, @user, allow_anonymous: true)
    @kubectl = K8::Kubectl.new(@connection)
  end

  def apply_namespace
    @logger.info("Creating namespace: #{@project.namespace}", color: :yellow)
    namespace_yaml = K8::Namespace.new(@project).to_yaml
    @kubectl.apply_yaml(namespace_yaml)
  end

  def upload_registry_secrets
    @logger.info("Creating registry secret for #{@project.container_image_reference}", color: :yellow)
    provider = @project.build_provider
    result = Providers::GenerateConfigJson.execute(provider:)
    raise StandardError, result.message if result.failure?

    secret_yaml = K8::Secrets::RegistrySecret.new(@project, result.docker_config_json).to_yaml
    @kubectl.apply_yaml(secret_yaml)
  end

  def deploy_services
    @project.services.each do |service|
      deploy_service(service)
    end
  end

  def deploy_service(service)
    raise NotImplementedError, "Subclasses must implement #deploy_service"
  end

  def kill_one_off_containers
    @kubectl.call("-n #{@project.namespace} delete pods -l oneoff=true")
  end

  def predeploy
    return unless @project.predeploy_command.present?

    run_command(@project.predeploy_command, "predeploy")
  end

  def postdeploy
    return unless @project.postdeploy_command.present?

    run_command(@project.postdeploy_command, "postdeploy")
  end

  def run_command(command, type)
    @logger.info("Running command: `#{command}`...", color: :yellow)
    command_job = K8::Stateless::Command.new(@project, type, command).connect(@connection)
    command_job.delete_if_exists!
    @kubectl.apply_yaml(command_job.to_yaml)
    command_job.wait_for_completion
  end

  def complete_deployment!
    @deployment.completed!
    @project.deployed!
  end

  def setup_automatic_dns(service)
    Dns::AutoSetupService.new(service, connection: @connection, logger: @logger).call
  end
end
