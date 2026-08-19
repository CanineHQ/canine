module BillableEnforcement
  extend ActiveSupport::Concern

  private

  def enforce_plan_limit!(resource)
    return if current_account.within_plan_limit?(resource)

    redirect_to billing_path,
      alert: "You've reached the #{resource} limit for your plan. Please upgrade to add more."
  end
end
