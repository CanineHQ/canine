# frozen_string_literal: true


namespace :dev do
  namespace :faker do
    desc "Generate fake data for development (idempotent with seed)"
    task seed: :environment do
      unless Rails.env.development?
        raise "This rake file can only be run in development environment"
      end
      unless Rails.application.config.local_mode
        raise "This rake file can only be run in local mode"
      end

      print "Enter number of clusters: "
      clusters_count = gets.chomp.to_i

      print "Enter number of projects per cluster: "
      projects_per_cluster = gets.chomp.to_i

      print "Enter seed for random generation: "
      seed = gets.chomp.to_i

      Faker::Config.random = Random.new(seed)
      seeded_random = Random.new(seed)

      puts "\nGenerating fake data with seed: #{seed}"
      puts "  - #{clusters_count} clusters"
      puts "  - #{projects_per_cluster} projects per cluster"
      puts "  - 1-4 services per project (random)"

      dev_email = "dev@example.com"
      dev_password = "password123"

      # Find or create a dev user and account
      user = User.find_or_create_by!(email: dev_email) do |u|
        u.password = dev_password
        u.first_name = "Dev"
        u.last_name = "User"
      end

      account = Account.find_or_create_by!(slug: "dev-account") do |a|
        a.name = "Dev Account"
        a.owner = user
      end

      # Ensure user is associated with account
      AccountUser.find_or_create_by!(user: user, account: account)

      # Create a provider for the user (needed for projects)
      provider = Provider.find_or_create_by!(user: user, provider: "github") do |p|
        p.uid = "fake-uid-#{seed}"
        p.access_token = "fake-token-#{seed}"
        p.auth = { info: { nickname: "devuser" } }.to_json
      end

      clusters_count.times do |cluster_idx|
        cluster_name = "cluster-#{Faker::Hacker.adjective}-#{cluster_idx}".parameterize

        cluster = Cluster.find_or_create_by!(account: account, name: cluster_name) do |c|
          c.status = :running
          c.cluster_type = :k8s
          c.kubeconfig = { fake: true, cluster_index: cluster_idx }.to_json
        end

        puts "  Created cluster: #{cluster.name}"

        projects_per_cluster.times do |project_idx|
          project_name = "#{Faker::App.name.parameterize}-#{project_idx}"
          namespace = "ns-#{project_name}"
          repo_name = "#{Faker::Internet.username(specifier: 5..10).gsub(/[^a-z0-9]/i, '')}/#{Faker::App.name.parameterize}"

          # Find or create project directly (avoiding Projects::Create to skip external integrations)
          project = Project.find_by(cluster: cluster, name: project_name)
          unless project
            project = Project.new(
              cluster: cluster,
              name: project_name,
              namespace: namespace,
              repository_url: repo_name,
              branch: "main"
            )
            project.build_project_credential_provider(provider: provider)
            project.build_build_configuration(
              provider: provider,
              driver: "docker",
              build_type: "dockerfile",
              image_repository: repo_name
            )
            project.save!
          end

          # Generate 1-4 services per project
          services_count = seeded_random.rand(1..4)
          services_count.times do |service_idx|
            service_type = [ :web_service, :background_service, :cron_job ].sample(random: seeded_random)
            service_name = "#{Faker::Hacker.verb.parameterize}-svc-#{service_idx}"

            service = Service.find_by(project: project, name: service_name)
            unless service
              service = Service.new(
                project: project,
                name: service_name,
                service_type: service_type,
                status: :healthy,
                container_port: [ 3000, 8080, 4000, 5000 ].sample(random: seeded_random),
                replicas: seeded_random.rand(1..3)
              )
              if service_type == :cron_job
                service.command = "/bin/start"
                service.build_cron_schedule(schedule: "0 * * * *")
              end
              service.save!
            end
          end

          puts "    Created project: #{project.name} with #{services_count} services"
        end
      end

      total_projects = clusters_count * projects_per_cluster
      puts "\nDone! Created:"
      puts "  - #{clusters_count} clusters"
      puts "  - #{total_projects} projects"
      puts "\nLogin credentials:"
      puts "  Email:    #{dev_email}"
      puts "  Password: #{dev_password}"
    end
  end
end
