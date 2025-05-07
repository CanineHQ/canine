class AddOns::InstallJob < ApplicationJob
  def perform(add_on)
    AddOns::InstallHelmChart.execute(add_on:)
    # TODO: Restart the service
  end
end
