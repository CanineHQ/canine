module Billable
  extend ActiveSupport::Concern

  FREE_CLUSTER_LIMIT = 1
  FREE_TEAM_MEMBERS_LIMIT = 5

  PLAN_COUNTERS = {
    clusters: ->(account) { account.clusters.count },
    team_members: ->(account) { account.users.count }
  }.freeze

  included do
    enum :plan, { free: 0, pro: 1 }
  end

  def plan_limit(resource)
    case resource
    when :clusters
      pro? ? Float::INFINITY : FREE_CLUSTER_LIMIT
    when :team_members
      pro? ? Float::INFINITY : FREE_TEAM_MEMBERS_LIMIT
    end
  end

  def plan_usage(resource)
    counter = PLAN_COUNTERS[resource]
    return nil unless counter

    { current: counter.call(self), limit: plan_limit(resource) }
  end

  def within_plan_limit?(resource)
    counter = PLAN_COUNTERS[resource]
    return true unless counter

    counter.call(self) < plan_limit(resource)
  end

  def billable_clusters_count
    [ clusters.count - FREE_CLUSTER_LIMIT, 0 ].max
  end

  def active_subscription?
    subscription_status.in?(%w[active trialing])
  end

  def needs_subscription?
    clusters.count > FREE_CLUSTER_LIMIT && !active_subscription?
  end
end
