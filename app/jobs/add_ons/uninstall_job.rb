class AddOns::UninstallJob < ApplicationJob
  def perform(add_on, user_id)
    user = User.find(user_id)
    connection = K8::Connection.new(add_on, user)
    AddOns::UninstallHelmChart.execute(connection:)
  end
end
