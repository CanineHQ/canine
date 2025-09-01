# frozen_string_literal: true

require 'tempfile'
require 'ostruct'

module Builders
  class BuildCloud < Builders::Base
    attr_reader :build_cloud, :build_cloud_manager

    # @param connection [Object] An object that responds to #kubeconfig
    # @param build_cloud [BuildCloud] Optional BuildCloud model to use for namespace
    def initialize(build, build_cloud)
      super(build)
      @build_cloud = build_cloud
      @build_cloud_manager = K8::BuildCloudManager.new(build_cloud.cluster, build_cloud)
    end

    def setup
      @build_cloud_manager.create_local_builder!
    end

    def cleanup
      @build_cloud_manager.remove_local_builder!
    end

    def build_image(repository_path)
      @build_cloud_manager.create_local_builder!

      command = construct_buildx_command(project, repository_path)
      runner = Cli::RunAndLog.new(build, killable: build)
      runner.call(command.join(" "))
    end

    def construct_buildx_command(project, repository_path)
      command = [ "docker", "buildx", "build" ]
      command += [ "--builder", build_cloud.name ]
      command += [ "--platform", "linux/amd64,linux/arm64" ]
      command += [ "--push" ]  # Push directly to registry
      command += [ "--progress", "plain" ]
      command += [ "-t", project.container_image_reference ]
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
  end
end
