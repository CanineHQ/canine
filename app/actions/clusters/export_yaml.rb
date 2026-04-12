# frozen_string_literal: true

require "zip"

module Clusters
  class ExportYaml
    extend LightService::Action

    SENSITIVE_KEY_PATTERN = /TOKEN|SECRET|KEY|PASSWORD|DSN|CREDENTIALS/i
    SENSITIVE_URL_PATTERN = /:\/\/[^:]+:[^@]+@/

    expects :cluster, :include_configmaps, :include_secrets
    promises :zip_data, :filename

    executed do |context|
      cluster = context.cluster
      skip_kinds = []
      skip_kinds << "ConfigMap" unless context.include_configmaps
      skip_kinds << "Secret" unless context.include_secrets

      stringio = Zip::OutputStream.write_buffer do |zio|
        cluster.projects.each do |project|
          deployment = project.deployments.where(status: :completed).order(created_at: :desc).first
          next unless deployment&.has_manifests?

          deployment.manifests.each do |key, yaml_content|
            manifest = YAML.safe_load(yaml_content)
            next if manifest.is_a?(Hash) && skip_kinds.include?(manifest["kind"])

            sanitized = sanitize_manifest(yaml_content)
            zio.put_next_entry("#{cluster.name}/#{project.namespace}/#{key.tr('/', '-')}.yaml")
            zio.write(sanitized)
          end
        end
      end
      stringio.rewind

      context.zip_data = stringio.read
      context.filename = "#{cluster.name}.zip"
    end

    class << self
      private

      def sanitize_manifest(yaml_content)
        manifest = YAML.safe_load(yaml_content)
        return yaml_content unless manifest.is_a?(Hash)

        strip_canine_labels(manifest)

        case manifest["kind"]
        when "Deployment" then sanitize_deployment(manifest)
        when "Secret" then sanitize_secret(manifest)
        when "ConfigMap" then sanitize_configmap(manifest)
        end

        manifest.to_yaml
      end

      def strip_canine_labels(manifest)
        labels = manifest.dig("metadata", "labels")
        return unless labels

        labels.delete("caninemanaged")
        manifest["metadata"].delete("labels") if labels.empty?
      end

      def sanitize_deployment(manifest)
        template = manifest.dig("spec", "template") || {}

        # Strip rolloutTimestamp annotation
        annotations = template.dig("metadata", "annotations")
        if annotations
          annotations.delete("rolloutTimestamp")
          template["metadata"].delete("annotations") if annotations.empty?
        end

        # Sanitize containers
        containers = template.dig("spec", "containers") || []
        containers.each do |container|
          container["image"] = "${IMAGE}" if container["image"]
          container.delete("imagePullPolicy")
          container.delete("resources") if container["resources"].nil? || container["resources"]&.empty?
        end
      end

      def sanitize_secret(manifest)
        return unless manifest["data"].is_a?(Hash)

        manifest["data"].transform_values! { |_| "<REPLACE_ME>" }
      end

      def sanitize_configmap(manifest)
        return unless manifest["data"].is_a?(Hash)

        manifest["data"].each do |key, value|
          next unless value.is_a?(String)

          if key.match?(SENSITIVE_KEY_PATTERN) || value.match?(SENSITIVE_URL_PATTERN)
            manifest["data"][key] = "<REPLACE_ME>"
          end
        end
      end
    end
  end
end
