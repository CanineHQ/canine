class Projects::HelmDeploymentJob < ApplicationJob
  DEPLOYABLE_RESOURCES = %w[ConfigMap Secrets Deployment CronJob Service Ingress Pv Pvc]
  def perform(deployment, user)
    project = deployment.project
    connection = K8::Connection.new(project, user, allow_anonymous: true)
    chart_builder = K8::Helm::ChartBuilder.new(
      project.name,
      deployment,
    ).connect(
      K8::Connection.new(project, user, allow_anonymous: true)
    )

    #chart_builder << apply_namespace(project)
    chart_builder << upload_registry_secrets(deployment)
    chart_builder << apply_config_map(project)
    chart_builder << apply_secrets(project)

    deploy_volumes(project, chart_builder)
    #chart_builder << predeploy(project, connection)
    deploy_services(project, chart_builder)
    chart_builder.install_chart(project.name)
  end

  def apply_namespace(project)
    K8::Namespace.new(project)
  end

  def upload_registry_secrets(deployment)
    project = deployment.project
    provider = project.build_provider
    result = Providers::GenerateConfigJson.execute(
      provider:,
    )
    raise StandardError, result.message if result.failure?

    K8::Secrets::RegistrySecret.new(project, result.docker_config_json)
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
end