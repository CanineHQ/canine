class Clusters::CheckConnectionJob < ApplicationJob
  queue_as :monitoring

  TIMEOUT = 20.seconds

  def perform(cluster)
    connection = K8::Connection.new(cluster, nil, allow_anonymous: true)
    reachable = Timeout.timeout(TIMEOUT) do
      # For Canine's own service account, reachable has to mean it can still act, not just authenticate.
      K8::Client.new(connection).can_connect? && (!cluster.manager_service_account? || K8::ManagerServiceAccount.full_access?(connection))
    end
    record(cluster, reachable)
  rescue StandardError, Timeout::Error => e
    Rails.logger.warn("Connection check failed for cluster #{cluster.name}: #{e.class} - #{e.message}")
    record(cluster, false)
  end

  private

  def record(cluster, reachable)
    if reachable
      cluster.update(unreachable_since: nil) if cluster.unreachable_since.present?
    elsif cluster.unreachable_since.blank?
      cluster.update(unreachable_since: Time.current)
    end
  end
end
