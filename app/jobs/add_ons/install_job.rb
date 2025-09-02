class AddOns::InstallJob < ApplicationJob
  def perform(add_on, user)
    needs_restart = add_on.installed?
    connection = K8::Connection.new(add_on, user)
    AddOns::InstallHelmChart.execute(connection:)

    if needs_restart
      service = K8::Helm::Service.create_from_add_on(connection)
      service.restart
    end
  end
end
