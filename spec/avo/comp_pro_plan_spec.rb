require "rails_helper"

RSpec.describe Avo::Actions::CompProPlan do
  include Devise::Test::IntegrationHelpers

  it "gives Pro for free and takes it back, leaving accounts that pay through Stripe alone" do
    free = create(:account)
    paying = create(:account, plan: :pro, subscription_status: :active, stripe_subscription_id: "sub_123")

    described_class.new.handle(query: [ free, paying ], fields: {}, current_user: nil, resource: nil)
    expect(free.reload).to have_attributes(plan: "pro", subscription_status: "active", complimentary?: true, needs_subscription?: false)
    expect(paying.reload.complimentary?).to be false

    Avo::Actions::RemoveCompedProPlan.new.handle(query: [ free, paying ], fields: {}, current_user: nil, resource: nil)
    expect(free.reload).to have_attributes(plan: "free", subscription_status: nil)
    expect(paying.reload).to have_attributes(plan: "pro", subscription_status: "active")
  end

  it "shows on an account's admin page", type: :request do
    admin = create(:user, admin: true)
    account = create(:account)
    sign_in admin
    get "#{Avo.configuration.root_path}/resources/accounts/#{account.id}"
    expect(response.body).to include("Give Pro for free", "Remove free Pro", "Subscription status")
  end
end
