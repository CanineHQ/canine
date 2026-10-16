# frozen_string_literal: true

module Namespaced
  # Rejects a cluster the user can't reach: one in an account they don't belong to, or outside their teams when the
  # account uses teams. cluster_id comes straight from request params, so it must be checked before anything is
  # created on the cluster.
  class ValidateClusterAccess
    extend LightService::Action
    expects :namespaced, :user

    executed do |context|
      namespaced = context.namespaced
      account_user = context.user.account_users.find_by(account_id: namespaced.cluster&.account_id)
      next if account_user && Clusters::VisibleToUser.execute(account_user:).clusters.exists?(id: namespaced.cluster_id)

      namespaced.errors.add(:cluster, "not found")
      context.fail_and_return!("Cluster not found")
    end
  end
end
