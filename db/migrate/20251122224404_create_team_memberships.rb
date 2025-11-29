class CreateTeamMemberships < ActiveRecord::Migration[7.2]
  def change
    create_table :team_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true

      t.timestamps
    end

    add_index :team_memberships, [ :user_id, :team_id ], unique: true
  end
end
