module Webhooks
  class StripeController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_user!
    skip_before_action :check_password_change_required

    def create
      return head :not_found unless Rails.configuration.cloud_mode

      payload = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

      event = Stripe::Webhook.construct_event(
        payload, sig_header, ENV["STRIPE_WEBHOOK_SECRET"]
      )

      handle_event(event)
      head :ok
    rescue Stripe::SignatureVerificationError
      head :bad_request
    rescue JSON::ParserError
      head :bad_request
    end

    private

    def handle_event(event)
      case event.type
      when "checkout.session.completed"
        handle_checkout_completed(event.data.object)
      when "customer.subscription.updated"
        handle_subscription_updated(event.data.object)
      when "customer.subscription.deleted"
        handle_subscription_deleted(event.data.object)
      end
    end

    def handle_checkout_completed(session)
      account = Account.find_by(id: session.metadata["account_id"])
      return unless account

      subscription = Stripe::Subscription.retrieve(session.subscription)

      account.update!(
        stripe_subscription_id: subscription.id,
        subscription_status: subscription.status,
        plan: :pro
      )
    end

    def handle_subscription_updated(subscription)
      account = Account.find_by(stripe_subscription_id: subscription.id)
      return unless account

      account.update!(subscription_status: subscription.status)
    end

    def handle_subscription_deleted(subscription)
      account = Account.find_by(stripe_subscription_id: subscription.id)
      return unless account

      account.update!(
        plan: :free,
        subscription_status: :canceled,
        stripe_subscription_id: nil
      )
    end
  end
end
