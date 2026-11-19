# Takes back a free Pro plan (Avo::Actions::CompProPlan). Accounts paying through Stripe are left alone: cancel those
# in Stripe, which updates the account through its webhook.
class Avo::Actions::RemoveCompedProPlan < Avo::BaseAction
  self.name = "Remove free Pro"
  self.message = "These accounts go back to the free plan."
  self.confirm_button_label = "Remove"

  def handle(query:, **)
    comped = query.select(&:complimentary?)
    comped.each { |account| account.update!(plan: :free, subscription_status: nil) }

    if comped.size < query.size
      warn "Only accounts given Pro for free were changed; cancel paid plans in Stripe."
    else
      succeed "Back on the free plan."
    end
  end
end
