namespace :dev_environment do
  desc "Enable Cloud Development Environment feature"
  task enable: :environment do
    Flipper.enable(:cloud_dev_environment)
    puts "✅ Cloud Development Environment feature enabled globally"
  end

  desc "Disable Cloud Development Environment feature"
  task disable: :environment do
    Flipper.disable(:cloud_dev_environment)
    puts "❌ Cloud Development Environment feature disabled globally"
  end

  desc "Enable Cloud Development Environment for a specific account"
  task :enable_for_account, [ :account_id ] => :environment do |_t, args|
    account = Account.find(args[:account_id])
    Flipper.enable_actor(:cloud_dev_environment, account)
    puts "✅ Cloud Development Environment enabled for account: #{account.name} (ID: #{account.id})"
  end

  desc "Disable Cloud Development Environment for a specific account"
  task :disable_for_account, [ :account_id ] => :environment do |_t, args|
    account = Account.find(args[:account_id])
    Flipper.disable_actor(:cloud_dev_environment, account)
    puts "❌ Cloud Development Environment disabled for account: #{account.name} (ID: #{account.id})"
  end

  desc "Check Cloud Development Environment feature status"
  task status: :environment do
    if Flipper.enabled?(:cloud_dev_environment)
      puts "✅ Cloud Development Environment is ENABLED globally"
    else
      puts "❌ Cloud Development Environment is DISABLED globally"
    end

    enabled_accounts = Account.all.select { |account| Flipper.enabled?(:cloud_dev_environment, account) }
    if enabled_accounts.any?
      puts "\nEnabled for #{enabled_accounts.count} account(s):"
      enabled_accounts.each do |account|
        puts "  - #{account.name} (ID: #{account.id})"
      end
    end
  end
end
