# frozen_string_literal: true

require 'shellwords'

class Projects::BuildJob < ApplicationJob
  queue_as :default
  class BuildFailure < StandardError; end

  def perform(build, user)
    project = build.project
    build.in_progress!
    # If its a container registry deploy, we don't need to build the docker image
    if project.container_registry?
      build.info("Skipping build for #{project.name} because it's a deploying from a container registry")
    else
      project_credential_provider = project.project_credential_provider
      project_credential_provider.used!

      # Initialize the Docker builder
      image_builder = if project.build_configuration&.k8s?
        build.info("Driver: Kubernetes (#{project.build_configuration.build_cloud.friendly_name})", color: :green)
        Builders::BuildCloud.new(build, project.build_configuration.build_cloud)
      elsif project.build_configuration.docker?
        build.info("Driver: Docker", color: :green)
        Builders::Docker.new(build)
      else
        build.info("Driver: Canine Cloud", color: :green)
        Builders::Cloud.new(build)
      end

      image_builder.setup
      # Login to registry
      image_builder.login_to_registry

      # Clone repository and build
      clone_repository_and_build_image(project, build, image_builder)
      image_builder.cleanup
    end

    complete_build!(build, user)
    # TODO: Step 7: Optionally, add post-deploy tasks or slack notifications
  rescue StandardError => e
    # Don't overwrite status if it was already set to killed
    unless build.killed?
      build.error(e.message)
      build.failed!
    end
    raise e
  end

  private

  def project_git(project)
    project_credential_provider = project.project_credential_provider
    base_url = project_credential_provider.provider.github? ? "github.com" : "gitlab.com"
    "https://#{project_credential_provider.username}:#{project_credential_provider.access_token}@#{base_url}/#{project.repository_url}.git"
  end

  def git_clone(project, build, repository_path)
    # Construct the git clone command with OAuth token
    git_clone_command = %w[git clone --depth 1 --branch] +
                        [ project.branch, project_git(project), repository_path ]

    # Execute the git clone command with killable support
    runner = Cli::RunAndLog.new(build, killable: build)
    runner.call(git_clone_command.join(" "))
  rescue Cli::CommandFailedError => e
    raise BuildFailure, "Failed to clone repository: #{e.message}"
  end


  def complete_build!(build, user)
    build.completed!
    deployment = Deployment.create!(build:)
    Projects::DeploymentJob.perform_later(deployment, user)
  end

  def clone_repository_and_build_image(project, build, image_builder)
    Dir.mktmpdir do |repository_path|
      build.info("Cloning repository: #{project.repository_url} to #{repository_path}", color: :yellow)

      git_clone(project, build, repository_path)

      # Use the Docker builder to build the image
      image_builder.build_image(repository_path)
    end
  end
end
