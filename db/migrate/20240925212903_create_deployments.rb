class CreateDeployments < ActiveRecord::Migration[7.2]
  def change
    create_table :deployments do |t|
      t.references :build, null: false, foreign_key: true
      t.integer :status, default: 0, null: false

      t.timestamps
    end
  end
end
