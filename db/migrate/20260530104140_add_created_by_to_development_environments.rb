class AddCreatedByToDevelopmentEnvironments < ActiveRecord::Migration[7.2]
  def change
    add_reference :development_environments, :created_by, null: true, foreign_key: { to_table: :users }

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE development_environments
          SET created_by_id = providers.user_id
          FROM providers
          WHERE development_environments.git_provider_id = providers.id
        SQL
      end
    end

    change_column_null :development_environments, :created_by_id, false
  end
end
