# Gives an account the Pro plan for free: Pro with an active subscription and no Stripe subscription behind it, so
# Stripe's webhooks and StripeSyncUsageJob (which only act on a stripe_subscription_id) leave it alone
class Avo::Actions::CompProPlan < Avo::BaseAction
  self.name = "Give Pro for free"
  self.message = "These accounts get the Pro plan without paying, until you remove it."
  self.confirm_button_label = "Give Pro"

  def handle(query:, **)
    paying = query.select { |account| account.stripe_subscription_id.present? }
    (query - paying).each { |account| account.update!(plan: :pro, subscription_status: :active) }

    if paying.any?
      warn "Skipped #{paying.map(&:name).to_sentence}: already paying through Stripe."
    else
      succeed "Pro plan given for free."
    end
  end
end
