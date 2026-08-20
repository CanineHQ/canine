class Accounts::BillingController < ApplicationController
  def show
  end

  def checkout
    ensure_stripe_customer!

    session = Stripe::Checkout::Session.create(
      customer: current_account.stripe_customer_id,
      mode: "subscription",
      line_items: [ {
        price: ENV["STRIPE_CLUSTER_PRICE_ID"],
        quantity: [ current_account.billable_clusters_count, 1 ].max
      } ],
      success_url: billing_url + "?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: billing_url,
      metadata: { account_id: current_account.id }
    )

    redirect_to session.url, allow_other_host: true, status: :see_other
  end

  def portal
    ensure_stripe_customer!

    session = Stripe::BillingPortal::Session.create(
      customer: current_account.stripe_customer_id,
      return_url: billing_url
    )

    redirect_to session.url, allow_other_host: true, status: :see_other
  end

  private

  def ensure_stripe_customer!
    return if current_account.stripe_customer_id.present?

    customer = Stripe::Customer.create(
      email: current_user.email,
      name: current_account.name,
      metadata: { account_id: current_account.id, account_name: current_account.name }
    )
    current_account.update!(stripe_customer_id: customer.id)
  end
end
