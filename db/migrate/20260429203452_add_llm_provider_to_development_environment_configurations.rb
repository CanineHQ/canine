class AddLlmProviderToDevelopmentEnvironmentConfigurations < ActiveRecord::Migration[7.2]
  def change
    add_column :development_environment_configurations, :llm_provider_id, :bigint
    add_index :development_environment_configurations, :llm_provider_id
    add_foreign_key :development_environment_configurations, :providers, column: :llm_provider_id
  end
end
