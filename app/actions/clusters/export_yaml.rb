# frozen_string_literal: true

require "zip"

module Clusters
  class ExportYaml
    extend LightService::Action

    expects :cluster
    promises :zip_data, :filename

    executed do |context|
      cluster = context.cluster

      stringio = Zip::OutputStream.write_buffer do |zio|
        cluster.projects.each do |project|
          deployment = project.deployments.where(status: :completed).order(created_at: :desc).first
          next unless deployment&.has_manifests?

          deployment.manifests.each do |key, yaml_content|
            zio.put_next_entry("#{cluster.name}/#{project.namespace}/#{key.tr('/', '-')}.yaml")
            zio.write(yaml_content)
          end
        end
      end
      stringio.rewind

      context.zip_data = stringio.read
      context.filename = "#{cluster.name}.zip"
    end
  end
end
