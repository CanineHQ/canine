class MoveDockerFieldsFromProjectToBuildConfiguration < ActiveRecord::Migration[7.2]
  def up
    # Add build fields to build_configurations (excluding docker_command which is used at runtime)
    add_column :build_configurations, :context_directory, :string, default: "./", null: false
    add_column :build_configurations, :dockerfile_path, :string, default: "./Dockerfile", null: false
    add_column :build_configurations, :build_type, :integer

    # Backfill data from projects to build_configurations
    reversible do |dir|
      dir.up do
        Project.reset_column_information
        BuildConfiguration.reset_column_information

        Project.find_each do |project|
          # Create build_configuration if it doesn't exist
          if project.build_configuration.nil?
            # Skip projects that don't have the required associations
            next unless project.project_credential_provider.present?

            BuildConfiguration.create!(
              project: project,
              provider: project.project_credential_provider.provider,
              driver: BuildConfiguration::DEFAULT_BUILDER,
              image_repository: project.repository_url,
              context_directory: project.docker_build_context_directory,
              dockerfile_path: project.dockerfile_path,
              build_type: :dockerfile,
            )
          else
            # Update existing build_configuration
            project.build_configuration.update!(
              context_directory: project.docker_build_context_directory,
              dockerfile_path: project.dockerfile_path,
              build_type: :dockerfile,
            )
          end
        end
      end
    end
    change_column_null :build_configurations, :build_type, false
  end

  def down
    # Remove build fields from build_configurations
    remove_column :build_configurations, :context_directory
    remove_column :build_configurations, :dockerfile_path
    remove_column :build_configurations, :build_type
  end
end
