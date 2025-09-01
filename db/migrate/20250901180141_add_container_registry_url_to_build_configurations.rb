class AddContainerRegistryUrlToBuildConfigurations < ActiveRecord::Migration[7.2]
  def change
    add_column :build_configurations, :image_repository, :string, null: false
    Project.all.each do |project|
      next if project.build_configuration.present?
      BuildConfiguration.create!(
        project: project,
        provider: project.project_credential_provider.provider,
        driver: 'docker',
        image_repository: project.repository_url
      )
    end
  end
end
