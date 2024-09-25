class CreateBuilds < ActiveRecord::Migration[7.2]
  def change
    create_table :builds do |t|
      t.references :project, null: false, foreign_key: true
      t.string :repository_url
      t.string :git_sha
      t.string :commit_message
      t.integer :status, default: 0
      t.string :commit_sha, null: false

      t.timestamps
    end
  end
end
