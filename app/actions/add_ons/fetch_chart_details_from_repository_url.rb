module AddOns
  class FetchChartDetailsFromRepositoryUrl
    extend LightService::Action

    expects :repo_url
    promises :charts

    executed do |context|
      repo_url = context.repo_url
      index_url = "#{repo_url.chomp('/')}/index.yaml"

      begin
        response = HTTParty.get(index_url, timeout: 10)

        unless response.success?
          context.fail_and_return!("Failed to fetch repository index: #{response.code}")
        end

        index_data = YAML.safe_load(response.body)

        unless index_data.is_a?(Hash) && index_data['entries'].is_a?(Hash)
          context.fail_and_return!("Invalid repository index format")
        end

        # Extract chart names and their available versions
        charts = {}
        index_data['entries'].each do |chart_name, versions|
          charts[chart_name] = versions.map { |v| v['version'] }.compact
        end

        context.charts = charts
      rescue HTTParty::Error, Net::OpenTimeout, SocketError => e
        context.fail_and_return!("Failed to fetch repository index: #{e.message}")
      rescue Psych::SyntaxError => e
        context.fail_and_return!("Invalid YAML format: #{e.message}")
      rescue StandardError => e
        context.fail_and_return!("An error occurred: #{e.message}")
      end
    end
  end
end
