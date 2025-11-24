class CreateTeamResources < ActiveRecord::Migration[7.2]
  def change
    create_table :team_resources do |t|
      t.references :team, null: false, foreign_key: true
      t.references :resourceable, polymorphic: true, null: false

      t.timestamps
    end

    add_index :team_resources, [ :team_id, :resourceable_type, :resourceable_id ], unique: true, name: 'index_team_resources_on_team_and_resourceable'
  end
end
