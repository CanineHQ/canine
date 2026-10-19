# frozen_string_literal: true

require 'tempfile'
require 'ostruct'

module Builders
  class BuildCloud < Builders::Base
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

    def login_to_registry
      return super unless project.build_configuration.cluster_registry?

      build.info("Pushing to the cluster's built-in registry", color: :yellow)
    end

    def build_image(repository_path)
      @build_cloud_manager.create_local_builder!

      metadata_file = File.join(repository_path, "buildx-metadata.json")
      command = construct_buildx_command(project, repository_path, metadata_file: metadata_file)
      runner = Cli::RunAndLog.new(build, killable: build)
      connection = build_cloud_manager.connection
      K8::Kubeconfig.with_kube_config(connection.kubeconfig, skip_tls_verify: connection.cluster.skip_tls_verify) do |kubeconfig_file|
        with_registry_docker_config do |docker_config_envs|
          runner.call(command, envs: { "KUBECONFIG" => kubeconfig_file.path }.merge(docker_config_envs))
        end
      end

      parse_digest_from_metadata(metadata_file)
    end

    def construct_buildx_command(project, repository_path, metadata_file: nil)
      command = [ "docker", "buildx", "build" ]
      command += [ "--builder", build_cloud_manager.build_cloud.name ]
      command += [ "--platform", "linux/amd64,linux/arm64" ]
      command += [ "--progress", "plain" ]
      build_configuration = project.build_configuration
      if build_configuration.cluster_registry?
        # The cluster registry serves plain HTTP, which only the image exporter can be told to push to
        command += [ "--output", "type=image,name=#{build_configuration.push_image_reference},push=true,registry.insecure=true" ]
      else
        command += [ "--push", "-t", project.container_image_reference ]
      end
      command += [ "-f", File.join(repository_path, project.build_configuration.dockerfile_path) ]

      # Add automatic build arguments
      automatic_build_args.each do |name, value|
        command += [ "--build-arg", "#{name}=#{value}" ]
      end

      # Add build arguments
      project.environment_variables.each do |envar|
        command += [ "--build-arg", "#{envar.name}=#{envar.value}" ]
      end

      # # Add cache options for better performance
      # cache_tag = "#{project.container_registry_url}:buildcache"
      # command += [ "--cache-from", "type=registry,ref=#{cache_tag}" ]
      # command += [ "--cache-to", "type=registry,ref=#{cache_tag},mode=max" ]

      command += [ "--metadata-file", metadata_file ] if metadata_file

      # Add build context
      command << File.join(repository_path, project.build_configuration.context_directory)

      command
    end

    private

    # `docker login` can't reach a registry inside the cluster, so buildx gets its credentials from a throwaway
    # config dir that shares everything else (builders, plugins) with the real one
    def with_registry_docker_config
      return yield({}) unless project.build_configuration.cluster_registry?

      registry = project.build_configuration.registry
      docker_config_dir = ENV["DOCKER_CONFIG"].presence || File.join(Dir.home, ".docker")
      Dir.mktmpdir("canine-docker-config") do |dir|
        Dir.glob(File.join(docker_config_dir, "*")).each do |entry|
          File.symlink(entry, File.join(dir, File.basename(entry))) unless File.basename(entry) == "config.json"
        end
        File.write(File.join(dir, "config.json"), Base64.decode64(registry.docker_config_json(ClusterRegistry::SERVICE_HOST)))
        yield({ "DOCKER_CONFIG" => dir })
      end
    end

    def parse_digest_from_metadata(metadata_file)
      return nil unless File.exist?(metadata_file)

      metadata = JSON.parse(File.read(metadata_file))
      metadata["containerimage.digest"]
    rescue JSON::ParserError
      nil
    end
  end
end
