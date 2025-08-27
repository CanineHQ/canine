class AddOns::UninstallJob < ApplicationJob
  def perform(add_on, user_id)
    user = User.find(user_id)
    AddOns::UninstallHelmChart.execute(add_on:, user:)
  end
end
