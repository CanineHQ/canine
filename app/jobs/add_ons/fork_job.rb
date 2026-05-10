class AddOns::ForkJob < ApplicationJob
  def perform(source_add_on, target_add_on, user)
    AddOns::ForkPostgres.execute(
      source_add_on: source_add_on,
      target_add_on: target_add_on,
      user: user
    )
  end
end
