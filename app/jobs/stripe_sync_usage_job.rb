class StripeSyncUsageJob < ApplicationJob
  queue_as :default

  def perform
    return unless Rails.configuration.cloud_mode

    Account.where(plan: :pro)
           .where(subscription_status: :active)
           .where("updated_at >= ?", 1.hour.ago)
           .find_each do |account|
      sync_account(account)
    end
  end

  private

  def sync_account(account)
    return unless account.stripe_subscription_id.present?

    subscription = Stripe::Subscription.retrieve(account.stripe_subscription_id)
    item = subscription.items.data.first

    new_quantity = account.billable_clusters_count

    if new_quantity > 0
      Stripe::SubscriptionItem.update(item.id, quantity: new_quantity)
    elsif new_quantity == 0
      Stripe::Subscription.cancel(subscription.id)
    end
  rescue Stripe::StripeError => e
    Rails.logger.error("Stripe sync failed for account #{account.id}: #{e.message}")
  end
end
