# frozen_string_literal: true

require 'open3'

module Builders
  class Docker < Builders::Base
    include Builders::Concerns::BuildpackBuilder

    # Build and push the Docker image
    def build_image(repository_path)
      if project.build_configuration.buildpacks?
        build_with_buildpacks(repository_path)
      else
        build_with_dockerfile(repository_path)
      end
    end

    private

    # Pack publishes during build with --publish flag
    def publish_during_build?
      true
    end

    def build_with_dockerfile(repository_path)
      docker_build_command = construct_buildx_command(repository_path)

      # Create a new instance of RunAndLog with the build object as the loggable and killable
      runner = Cli::RunAndLog.new(build, killable: build)

      # Call the runner with the command (joined as a string since RunAndLog expects a string)
      runner.call(docker_build_command.join(" "))
    rescue Cli::CommandFailedError => e
      raise "Docker build failed: #{e.message}"
    end

    def construct_buildx_command(repository_path)
      docker_build_command = [
        "docker",
        "--context=default",
        "buildx",
        "build",
        "--progress=plain",
        "--platform", "linux/amd64",
        "-t", project.container_image_reference,
        "-f", File.join(repository_path, project.build_configuration.dockerfile_path)
      ]

      # Add environment variables to the build command
      project.environment_variables.each do |envar|
        docker_build_command.push("--build-arg", "#{envar.name}=\"#{envar.value}\"")
      end

      docker_build_command.push("--push")

      # Add the build context directory at the end
      docker_build_command.push(File.join(repository_path, project.build_configuration.context_directory))
      Rails.logger.info("Docker build command: `#{docker_build_command.join(" ")}`")
      docker_build_command
    end
  end
end
