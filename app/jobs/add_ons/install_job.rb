class AddOns::InstallJob < ApplicationJob
  def perform(add_on)
    needs_restart = add_on.installed?
    AddOns::InstallHelmChart.execute(add_on:)

    if needs_restart
      service = K8::Helm::Service.create_from_add_on(add_on)
      service.restart
    end
  end
end
