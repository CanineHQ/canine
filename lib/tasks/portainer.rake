# frozen_string_literal: true

require 'httparty'
require 'yaml'
require 'tempfile'

PORTAINER_URL = "https://portainer.portainer.svc.cluster.local:9443"

namespace :portainer do
  desc 'Run Portainer task'
  task run: :environment do
    jwt = Portainer::Client.authenticate(
      provider_url: PORTAINER_URL,
      username: 'admin',
      auth_code: ENV['PORTAINER_PASSWORD']
    )

    if jwt.present?
      puts "JWT: #{jwt}"

      # Get Kubernetes config
      config_response = Portainer::Client.new(PORTAINER_URL, jwt).get_kubernetes_config

      if config_response.present?
        config_yaml = config_response.to_yaml

        # Save to temp file
        temp_file = Tempfile.new([ 'kubeconfig', '.yaml' ])
        temp_file.write(config_yaml)
        temp_file.close

        puts "Kubeconfig saved to: #{temp_file.path}"

        # Run kubectl command with the temp kubeconfig
        output = `KUBECONFIG=#{temp_file.path} kubectl get pods 2>&1`
        puts "\nKubectl output:"
        puts output

        # Clean up temp file
        temp_file.unlink

        puts "\nSUCCESSFULLY REACHED CLUSTER VIA PORTAINER"
      else
        puts "Error getting config: #{config_response.body}"
      end
    else
      puts "Error: #{response.code}"
      puts response.body
    end
  end
end
