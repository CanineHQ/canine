class AddOns::InstallJob < ApplicationJob
  def perform(add_on)
    AddOns::InstallHelmChart.execute(add_on:)
  end
end
