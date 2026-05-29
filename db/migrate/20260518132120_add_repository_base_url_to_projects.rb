class AddRepositoryBaseUrlToProjects < ActiveRecord::Migration[7.2]
  PROVIDER_TYPE_MAP = {
    "github" => 0,
    "gitlab" => 1,
    "bitbucket" => 2,
    "container_registry" => 3
  }.freeze

  def up
    add_column :projects, :repository_base_url, :string
    add_column :projects, :provider_type, :integer, null: false, default: 0

    Project.includes(project_credential_provider: :provider).find_each do |project|
      provider = project.project_credential_provider&.provider
      next unless provider

      project.update_columns(
        repository_base_url: provider.source_base_url,
        provider_type: PROVIDER_TYPE_MAP.fetch(provider.provider)
      )
    end
  end

  def down
    remove_column :projects, :repository_base_url
    remove_column :projects, :provider_type
    remove_column :projects, :source_type if column_exists?(:projects, :source_type)
  end
end
