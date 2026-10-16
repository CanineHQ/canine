# frozen_string_literal: true

module AddOns
  # The add-on's cluster_id comes straight from request params, so before anything else the user must be able to
  # reach that cluster: it must be in one of their accounts, and within their teams when the account uses teams.
  class VerifyPermissions
    extend LightService::Action
    expects :add_on, :user

    executed do |context|
      add_on = context.add_on
      account_user = context.user.account_users.find_by(account_id: add_on.cluster&.account_id)
      next if account_user && Clusters::VisibleToUser.execute(account_user:).clusters.exists?(id: add_on.cluster_id)

      add_on.errors.add(:cluster, "not found")
      context.fail_and_return!("Cluster not found")
    end
  end
end
