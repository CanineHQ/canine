# frozen_string_literal: true

module AddOns
  class ResetDemoJob < ApplicationJob
    queue_as :default

    def perform(add_on)
      return unless Flipper.enabled?(:demo_mode, add_on)
      return unless add_on.installed?

      user = add_on.account.owner
      connection = K8::Connection.new(add_on, user, allow_anonymous: true)

      # Uninstall the helm release (but keep the record and namespace)
      client = K8::Helm::Client.connect(connection, Cli::RunAndLog.new(add_on))
      charts = client.ls
      if charts.any? { |chart| chart['name'] == add_on.name }
        client.uninstall(add_on.name, namespace: add_on.namespace)
      end

      # Reinstall from scratch
      AddOns::InstallHelmChart.execute(connection:, force: true)
    end
  end
end
