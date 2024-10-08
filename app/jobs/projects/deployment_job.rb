require "base64"
require "json"

class Projects::DeploymentJob < ApplicationJob
  class DeploymentFailure < StandardError; end

  def perform(deployment)
    project = deployment.project
    kubeconfig = project.cluster.kubeconfig
    kubectl = create_kubectl(deployment, kubeconfig)

    # Upload container registry secrets
    upload_registry_secrets(kubectl, deployment)

    # Create namespace
    create_namespace(project, kubectl)

    predeploy(project, deployment)
    # For each of the projects services
    deploy_services(project, kubectl)

    deployment.completed!
  rescue StandardError => e
    deployment.info "Deployment failed: #{e.message}"
    deployment.failed!
  end

  private

  def create_namespace(project, kubectl)
    namespace_yaml = K8::Namespace.new(project).to_yaml
    kubectl.apply_yaml(namespace_yaml)
  end

  def predeploy(project, deployment)
    return unless project.predeploy_command.present?

    deployment.info "Running predeploy command: #{project.predeploy_command}"
    success = system(project.predeploy_command)

    return if success

    raise DeploymentFailure, "Predeploy command failed for project #{project.name}"
  end


  def create_kubectl(deployment, kubeconfig)
    runner = Cli::RunAndLog.new(deployment)
    K8::Kubectl.new(kubeconfig, runner)
  end

  def deploy_services(project, kubectl)
    project.services.each do |service|
      deploy_service(service, kubectl)
    end
  end

  def deploy_service(service, kubectl)
    if service.background_service?
      apply_deployment(service, kubectl)
    elsif service.cron_job?
      apply_cron_job(service, kubectl)
    elsif service.web_service?
      apply_deployment(service, kubectl)
      apply_service(service, kubectl)
      apply_ingress(service, kubectl)
    end
  end

  %w[Deployment CronJob Service Ingress].each do |resource_type|
    define_method(:"apply_#{resource_type.underscore}") do |service, kubectl|
      resource_yaml = K8::Stateless.const_get(resource_type).new(service).to_yaml
      kubectl.apply_yaml(resource_yaml)
    end
  end

  def upload_registry_secrets(kubectl, deployment)
    project = deployment.project
    docker_config_json = create_docker_config_json(project.user.github_username, project.user.github_access_token)
    secret_yaml = K8::Secrets::RegistrySecret.new(project, docker_config_json).to_yaml
    kubectl.apply_yaml(secret_yaml)
  end

  def create_docker_config_json(username, password)
    # First base64 encoding
    auth_value = Base64.strict_encode64("#{username}:#{password}")

    # Create the JSON structure
    docker_config = {
      "auths" => {
        "ghcr.io" => {
          "auth" => auth_value
        }
      }
    }

    # Second base64 encoding of the entire JSON
    Base64.strict_encode64(JSON.generate(docker_config))
  end
end
