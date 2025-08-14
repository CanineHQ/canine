# frozen_string_literal: true

require 'httparty'
require 'yaml'
require 'tempfile'

PORTAINER_URL = "https://portainer.portainer.svc.cluster.local:9443"

namespace :portainer do
  desc 'Run Portainer task'
  task run: :environment do
    response = HTTParty.post(
      "#{PORTAINER_URL}/api/auth",
      body: {
        username: 'admin',
        password: ENV['PORTAINER_PASSWORD']
      }.to_json,
      headers: {
        'Content-Type' => 'application/json'
      },
      verify: false
    )
    
    if response.code == 200
      jwt = JSON.parse(response.body)['jwt']
      puts "JWT: #{jwt}"
      
      # Get Kubernetes config
      config_response = HTTParty.get(
        "#{PORTAINER_URL}/api/kubernetes/config",
        headers: {
          'Authorization' => "Bearer #{jwt}"
        },
        verify: false
      )
      
      puts "Kubernetes Config Response: #{config_response.code}"
      
      if config_response.code == 200
        # Parse JSON and convert to YAML
        config_json = JSON.parse(config_response.body)
        config_yaml = config_json.to_yaml
        
        # Save to temp file
        temp_file = Tempfile.new(['kubeconfig', '.yaml'])
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
