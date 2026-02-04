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

    def build_image(repository_path)
      @build_cloud_manager.create_local_builder!

      metadata_file = File.join(repository_path, "buildx-metadata.json")
      command = construct_buildx_command(project, repository_path, metadata_file: metadata_file)
      runner = Cli::RunAndLog.new(build, killable: build)
      connection = build_cloud_manager.connection
      K8::Kubeconfig.with_kube_config(connection.kubeconfig, skip_tls_verify: connection.cluster.skip_tls_verify) do |kubeconfig_file|
        runner.call(command.join(" "), envs: { "KUBECONFIG" => kubeconfig_file.path })
      end

      parse_digest_from_metadata(metadata_file)
    end

    def construct_buildx_command(project, repository_path, metadata_file: nil)
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

      command += [ "--metadata-file", metadata_file ] if metadata_file

      # Add build context
      command << File.join(repository_path, project.build_configuration.context_directory)

      command
    end

    private

    def parse_digest_from_metadata(metadata_file)
      return nil unless File.exist?(metadata_file)

      metadata = JSON.parse(File.read(metadata_file))
      metadata["containerimage.digest"]
    rescue JSON::ParserError
      nil
    end
  end
end
