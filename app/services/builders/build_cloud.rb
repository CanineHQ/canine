# frozen_string_literal: true

require 'tempfile'
require 'ostruct'

module Builders
  class BuildCloud < Builders::Base
    include K8::Kubeconfig
    include Builders::Concerns::BuildpackBuilder

    attr_reader :build_cloud_manager

    def initialize(build, build_cloud_manager)
      super(build)
      @build_cloud_manager = build_cloud_manager
    end

    def setup
      @build_cloud_manager.create_local_builder!
    end

    def cleanup
      @build_cloud_manager.remove_local_builder!
    end

    def build_image(repository_path)
      @build_cloud_manager.create_local_builder!

      if project.build_configuration.buildpacks?
        build_with_buildpacks_on_k8s(repository_path)
      else
        build_with_dockerfile_on_k8s(repository_path)
      end
    end

    def kubeconfig
      build_cloud_manager.connection.kubeconfig
    end

    private

    # Pack publishes during build with --publish flag
    def publish_during_build?
      true
    end

    # Override to run pack command with KUBECONFIG
    def run_pack_command(command)
      runner = Cli::RunAndLog.new(build, killable: build)
      with_kube_config do |kubeconfig_file|
        # TODO: Verify pack works with k8s builder context
        # Pack uses docker daemon directly, may need additional configuration
        # to work with kubernetes builders
        runner.call(command, envs: { "KUBECONFIG" => kubeconfig_file.path })
      end
    rescue Cli::CommandFailedError => e
      raise Projects::BuildJob::BuildFailure, "Pack build failed: #{e.message}"
    end

    def build_with_buildpacks_on_k8s(repository_path)
      build.info("Note: Using pack with Kubernetes builder", color: :yellow)
      build_with_buildpacks(repository_path)
    end

    def build_with_dockerfile_on_k8s(repository_path)
      command = construct_buildx_command(project, repository_path)
      runner = Cli::RunAndLog.new(build, killable: build)
      with_kube_config do |kubeconfig_file|
        runner.call(command.join(" "), envs: { "KUBECONFIG" => kubeconfig_file.path })
      end
    end

    def construct_buildx_command(project, repository_path)
      command = [ "docker", "buildx", "build" ]
      command += [ "--builder", build_cloud_manager.build_cloud.name ]
      command += [ "--platform", "linux/amd64,linux/arm64" ]
      command += [ "--push" ]  # Push directly to registry
      command += [ "--progress", "plain" ]
      command += [ "-t", project.container_image_reference ]
      command += [ "-f", File.join(repository_path, project.build_configuration.dockerfile_path) ]

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
      command << File.join(repository_path, project.build_configuration.context_directory)

      command
    end
  end
end
