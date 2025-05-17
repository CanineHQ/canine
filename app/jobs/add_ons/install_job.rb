class AddOns::InstallJob < ApplicationJob
  def perform(add_on)
    AddOns::InstallHelmChart.execute(add_on:)
    # TODO: Restart the service
    service = K8::Helm::Service.create_from_add_on(add_on)
    service.restart
  end
end
