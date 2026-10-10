# frozen_string_literal: true

# Connects a cluster from a kubeconfig and kicks off installation of system packages.
# params: name, kubeconfig (YAML string or hash), cluster_type ("k8s" default), ip_address (k3s only)
module Api
  module Clusters
    class Create
      extend LightService::Action
      expects :account_user, :params
      promises :cluster

      executed do |context|
        params = context.params.to_h.with_indifferent_access
        account = context.account_user.account

        if Rails.configuration.cloud_mode && !account.within_plan_limit?(:clusters)
          context.fail_and_return!("You've reached the cluster limit for your plan. Upgrade your plan to add more.")
        end

        kubeconfig = params[:kubeconfig].is_a?(Hash) ? params[:kubeconfig].to_hash : params[:kubeconfig]
        if kubeconfig.is_a?(String)
          begin
            kubeconfig = YAML.safe_load(kubeconfig)
          rescue Psych::SyntaxError => e
            context.fail_and_return!("Invalid kubeconfig YAML: #{e.message}")
          end
        end
        context.fail_and_return!("Invalid kubeconfig: expected a YAML mapping") unless kubeconfig.is_a?(Hash)

        # A raw k3s.yaml points at 127.0.0.1; point it at the server's public IP instead.
        if params[:ip_address].present?
          kubeconfig.dig("clusters", 0, "cluster")&.store("server", "https://#{params[:ip_address]}:6443")
        end

        result = ::Clusters::Create.call(
          ActionController::Parameters.new(
            cluster: {
              name: params[:name],
              cluster_type: params[:cluster_type].presence || "k8s",
              kubeconfig: kubeconfig.to_yaml,
              kubeconfig_yaml_format: "true"
            }
          ),
          context.account_user
        )

        if result.failure?
          context.fail_and_return!(result.cluster&.errors&.full_messages&.to_sentence.presence || result.message)
        end

        context.cluster = result.cluster
        ::Clusters::InstallJob.perform_later(context.cluster, context.account_user.user)
      end
    end
  end
end
