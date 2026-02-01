class Deployments::HelmDeploymentService < Deployments::BaseDeploymentService
  def deploy
    setup_connection
    setup_chart_builder

    apply_namespace if @project.managed_namespace?
    upload_registry_secrets
    apply_config_and_secrets

    deploy_volumes
    predeploy
    deploy_services
    @chart_builder.install_chart(@project.name)
    setup_dns_for_services
    kill_one_off_containers
    postdeploy

    mark_services_healthy
    complete_deployment!
  rescue StandardError => e
    @logger.error("Deployment failed: #{e.message}")
    puts e.full_message
    @deployment.failed!
  end

  private

  def setup_chart_builder
    @chart_builder = K8::Helm::ChartBuilder.new(
      @project.name,
      @deployment.version,
      @deployment
    ).connect(@connection)

    @chart_builder.register_before_install do |yaml_content|
      @deployment.add_manifest(yaml_content)
    end
  end

  def apply_config_and_secrets
    @chart_builder << build_resource("ConfigMap", @project)
    @chart_builder << build_resource("Secrets", @project)
  end

  def build_resource(resource_type, target)
    K8::Stateless.const_get(resource_type).new(target)
  end

  def deploy_volumes
    @project.volumes.each do |volume|
      @chart_builder << build_resource("Pv", volume)
      @chart_builder << build_resource("Pvc", volume)
      volume.deployed!
    rescue StandardError => e
      volume.failed!
      raise e
    end
  end

  def deploy_service(service)
    if service.background_service?
      @chart_builder << build_resource("Deployment", service)
    elsif service.cron_job?
      @chart_builder << build_resource("CronJob", service)
    elsif service.web_service?
      @chart_builder << build_resource("Deployment", service)
      @chart_builder << build_resource("Service", service)
      if service.domains.any? && service.allow_public_networking?
        @chart_builder << build_resource("Ingress", service)
      end
    end
  end

  def mark_services_healthy
    @project.services.each(&:healthy!)
  end

  def setup_dns_for_services
    @project.services.each do |service|
      setup_automatic_dns(service)
    end
  end
end
