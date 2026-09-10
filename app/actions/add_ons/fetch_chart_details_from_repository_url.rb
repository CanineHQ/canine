module AddOns
  class FetchChartDetailsFromRepositoryUrl
    extend LightService::Action

    expects :repo_url
    promises :charts

    executed do |context|
      repo_url = context.repo_url

      if repo_url.start_with?("oci://")
        fetch_oci_tags(context, repo_url)
      else
        fetch_http_index(context, repo_url)
      end
    end

    def self.fetch_oci_tags(context, repo_url)
      # Parse OCI URL: oci://registry/path/to/chart -> registry, path/to/chart
      uri_part = repo_url.sub("oci://", "")
      parts = uri_part.split("/")
      registry = parts.first
      image_path = parts[1..].join("/")
      chart_name = parts.last

      begin
        token = fetch_oci_token(registry, image_path)
        headers = { "Accept" => "application/json" }
        headers["Authorization"] = "Bearer #{token}" if token

        tags_url = "https://#{registry}/v2/#{image_path}/tags/list"
        response = HTTParty.get(tags_url, timeout: 10, headers: headers)

        unless response.success?
          context.fail_and_return!("Failed to fetch OCI tags (#{response.code}). The registry may require authentication.")
          return
        end

        data = JSON.parse(response.body)
        tags = data["tags"] || []

        # Sort tags by semver descending, falling back to string sort
        sorted_tags = tags.sort_by { |t| Gem::Version.new(t) rescue Gem::Version.new("0") }.reverse

        context.charts = { chart_name => sorted_tags }
      rescue HTTParty::Error, Net::OpenTimeout, SocketError => e
        context.fail_and_return!("Failed to fetch OCI tags: #{e.message}")
      rescue JSON::ParserError => e
        context.fail_and_return!("Invalid response from OCI registry: #{e.message}")
      rescue StandardError => e
        context.fail_and_return!("An error occurred: #{e.message}")
      end
    end

    # Docker v2 registries require a bearer token even for public images.
    # We request an anonymous token via the WWW-Authenticate challenge.
    def self.fetch_oci_token(registry, image_path)
      challenge_response = HTTParty.get("https://#{registry}/v2/", timeout: 5)
      return nil if challenge_response.success?

      www_auth = challenge_response.headers["www-authenticate"]
      return nil unless www_auth

      # Parse: Bearer realm="https://...",service="...",scope="..."
      realm = www_auth[/realm="([^"]+)"/, 1]
      service = www_auth[/service="([^"]+)"/, 1]
      return nil unless realm

      token_url = "#{realm}?service=#{service}&scope=repository:#{image_path}:pull"
      token_response = HTTParty.get(token_url, timeout: 5)
      return nil unless token_response.success?

      JSON.parse(token_response.body)["token"]
    rescue StandardError
      nil
    end

    def self.fetch_http_index(context, repo_url)
      index_url = "#{repo_url.chomp('/')}/index.yaml"

      begin
        response = HTTParty.get(index_url, timeout: 10)

        unless response.success?
          context.fail_and_return!("Failed to fetch repository index: #{response.code}")
          return
        end

        index_data = YAML.safe_load(response.body)

        unless index_data.is_a?(Hash) && index_data['entries'].is_a?(Hash)
          context.fail_and_return!("Invalid repository index format")
          return
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
