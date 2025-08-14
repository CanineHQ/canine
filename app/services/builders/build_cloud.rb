# frozen_string_literal: true

require 'tempfile'
require 'ostruct'

module Builders
  class BuildCloud < Base
    # @param connection [Object] An object that responds to #kubeconfig
    # @param build_cloud [BuildCloud] Optional BuildCloud model to use for namespace
    def initialize(build)
      super(build)
    end

    def build_image(repository_path)
      command = construct_buildx_command(project, repository_path)
      runner = Cli::RunAndLog.new(build, killable: build)
      runner.call(command.join(" "))
    end

    def construct_buildx_command(project, repository_path)
      command = [ "docker", "buildx", "build" ]
      command += [ "--builder", K8::BuildCloudManager::BUILDKIT_BUILDER_NAME ]
      command += [ "--platform", "linux/amd64,linux/arm64" ]
      command += [ "--push" ]  # Push directly to registry
      command += [ "--progress", "plain" ]
      command += [ "-t", project.container_registry_url ]
      command += [ "-f", File.join(repository_path, project.dockerfile_path) ]

      # Add build arguments
      project.environment_variables.each do |envar|
        command += [ "--build-arg", "#{envar.name}=#{envar.value}" ]
      end

      # # Add cache options for better performance
      # cache_tag = "#{project.container_registry_url}:buildcache"
      # command += [ "--cache-from", "type=registry,ref=#{cache_tag}" ]
      # command += [ "--cache-to", "type=registry,ref=#{cache_tag},mode=max" ]
      command += [ "--push" ]

      # Add build context
      command << File.join(repository_path, project.docker_build_context_directory)

      command
    end

    def push_image
      puts "already pushed"
    end
  end
end
