class AddOns::InstallJob < ApplicationJob
  def perform(add_on, user, skip_schema_validation: false)
    needs_restart = add_on.installed?
    connection = K8::Connection.new(add_on, user, allow_anonymous: true)
    AddOns::InstallHelmChart.execute(connection:, skip_schema_validation:)

    if needs_restart
      service = K8::Helm::Service.create_from_add_on(connection)
      service.restart
    end
  end
end
