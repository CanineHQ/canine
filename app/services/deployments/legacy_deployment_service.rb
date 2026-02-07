class Deployments::LegacyDeploymentService < Deployments::BaseDeploymentService
  def initialize(deployment, user)
    super
    @marked_resources = []
  end

  def deploy
    setup_connection

    apply_namespace if @project.managed_namespace?
    upload_registry_secrets
    apply_resource("ConfigMap", @project)
    apply_resource("Secrets", @project)

    deploy_volumes
    predeploy
    deploy_services
    sweep_unused_resources
    kill_one_off_containers
    postdeploy

    complete_deployment!
  rescue StandardError => e
    # Don't overwrite status if it was already set to killed
    unless @deployment.killed?
      @logger.error("Deployment failed: #{e.message}")
      puts e.full_message
      @deployment.failed!
    end
  end

  private

  def setup_connection
    @connection = K8::Connection.new(@project, @user, allow_anonymous: true)
    runner = Cli::RunAndLog.new(@deployment, killable: @deployment)
    @kubectl = K8::Kubectl.new(@connection, runner)
  end

  def apply_resource(resource_type, target)
    @logger.info("Creating #{resource_type}: #{target.name}", color: :yellow)
    resource = K8::Stateless.const_get(resource_type).new(target)
    @kubectl.apply_yaml(resource.to_yaml)
    @marked_resources << resource
  end

  def deploy_volumes
    @project.volumes.each do |volume|
      apply_resource("Pv", volume)
      apply_resource("Pvc", volume)
      volume.deployed!
    rescue StandardError => e
      @logger.error("Volume deployment failed: #{e.message}")
      volume.failed!
      raise e
    end
  end

  def deploy_service(service)
    if service.background_service?
      apply_resource("Deployment", service)
      restart_deployment(service)
    elsif service.cron_job?
      apply_resource("CronJob", service)
    elsif service.web_service?
      apply_resource("Deployment", service)
      apply_resource("Service", service)
      if service.domains.any? && service.allow_public_networking?
        apply_resource("Ingress", service)
      end
      restart_deployment(service)
      setup_automatic_dns(service)
    end
    service.healthy!
  end

  def restart_deployment(service)
    @logger.info("Restarting deployment: #{service.name}", color: :yellow)
    @kubectl.call("-n #{service.project.namespace} rollout restart deployment/#{service.name}")
  end

  def sweep_unused_resources
    resources_to_sweep = DEPLOYABLE_RESOURCES.reject { |r| [ "Pv" ].include?(r) }
    kubectl = K8::Kubectl.new(@connection)

    resources_to_sweep.each do |resource_type|
      results = YAML.safe_load(kubectl.call("get #{resource_type.downcase} -o yaml -n #{@project.namespace}"))
      results["items"].each do |resource|
        if @marked_resources.select { |r|
          r.is_a?(K8::Stateless.const_get(resource_type))
        }.none? { |applied_resource|
          applied_resource.name == resource["metadata"]["name"]
        } && resource.dig("metadata", "labels", "caninemanaged") == "true"
          @logger.info("Deleting #{resource_type}: #{resource['metadata']['name']}", color: :yellow)
          kubectl.call("delete #{resource_type.downcase} #{resource['metadata']['name']} -n #{@project.namespace}")
        end
      end
    end
  end
end
