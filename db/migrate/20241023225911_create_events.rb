class CreateEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :events do |t|
      t.references :user, null: false
      t.references :project, null: false
      t.references :eventable, polymorphic: true, null: false
      t.integer :event_action, null: false
      t.timestamps
    end
  end
end
