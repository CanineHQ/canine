class AddOns::UninstallJob < ApplicationJob
  def perform(add_on)
    AddOns::UninstallHelmChart.execute(add_on:)
  end
end