# frozen_string_literal: true

# Installs a Helm chart as an add-on on a cluster. Installation continues in the background.
# params: name, chart_url, version, repository_url, values_yaml
module Api
  module AddOns
    class Create
      extend LightService::Action
      expects :cluster, :user, :params
      promises :add_on

      executed do |context|
        params = context.params.to_h.with_indifferent_access

        add_on = AddOn.new(
          cluster: context.cluster,
          name: params[:name],
          chart_url: params[:chart_url],
          version: params[:version],
          repository_url: params[:repository_url],
          managed_namespace: true
        )
        context.add_on = add_on

        if params[:values_yaml].present?
          begin
            add_on.values = YAML.safe_load(params[:values_yaml])
          rescue Psych::SyntaxError => e
            context.fail_and_return!("Invalid YAML in values_yaml: #{e.message}")
          end
        end

        result = ::AddOns::Create.call(add_on, context.user)
        if result.failure?
          context.fail_and_return!(add_on.errors.full_messages.to_sentence.presence || result.message)
        end

        ::AddOns::InstallJob.perform_later(add_on, context.user)
      end
    end
  end
end
