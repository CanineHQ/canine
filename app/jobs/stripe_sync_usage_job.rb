class StripeSyncUsageJob < ApplicationJob
  queue_as :default

  def perform(account)
    return unless Rails.configuration.cloud_mode
    return unless account.stripe_subscription_id.present?
    return unless account.active_subscription?

    subscription = Stripe::Subscription.retrieve(account.stripe_subscription_id)
    item = subscription.items.data.first

    new_quantity = account.billable_clusters_count

    if new_quantity > 0
      Stripe::SubscriptionItem.update(item.id, quantity: new_quantity)
    elsif new_quantity == 0
      # Back to free tier usage, cancel the subscription
      Stripe::Subscription.cancel(subscription.id)
    end
  end
end
