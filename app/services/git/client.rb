class Git::Client
  def self.from_provider(provider:, repository_url:)
    if provider.github?
      Git::Github::Client.new(access_token: provider.access_token, repository_url:, api_base_url: provider.api_base_url)
    elsif provider.gitlab?
      Git::Gitlab::Client.new(access_token: provider.access_token, repository_url:, api_base_url: provider.api_base_url)
    elsif provider.bitbucket?
      Git::Bitbucket::Client.new(access_token: provider.access_token, repository_url:, api_base_url: provider.api_base_url)
    else
      raise "Unsupported Git provider: #{provider}"
    end
  end

  def self.from_project(project)
    if project.project_credential_provider.provider.github?
      Git::Github::Client.from_project(project)
    elsif project.project_credential_provider.provider.gitlab?
      Git::Gitlab::Client.from_project(project)
    elsif project.project_credential_provider.provider.bitbucket?
      Git::Bitbucket::Client.from_project(project)
    else
      raise "Unsupported Git provider: #{project.project_credential_provider.provider}"
    end
  end
end
