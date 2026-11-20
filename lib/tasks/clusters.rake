namespace :clusters do
  desc "Replace user-supplied kubeconfigs with Canine's own service account credentials"
  task bootstrap_service_accounts: :environment do
    Cluster.where(external_id: nil).where.not(status: %i[destroying deleted]).find_each do |cluster|
      next if cluster.in_cluster? || cluster.kubeconfig.blank?

      result = Clusters::BootstrapServiceAccount.execute(cluster:, user: cluster.account.owner)
      if result.success? && cluster.save
        puts "#{cluster.name} (#{cluster.id}): now using the canine-manager service account"
      else
        puts "#{cluster.name} (#{cluster.id}): skipped - #{cluster.errors.full_messages.join(', ').presence || result.message}"
      end
    rescue StandardError => e
      puts "#{cluster.name} (#{cluster.id}): skipped - #{e.message}"
    end
  end
end
