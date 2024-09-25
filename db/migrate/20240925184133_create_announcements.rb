class CreateAnnouncements < ActiveRecord::Migration[7.1]
  def change
    create_table :announcements do |t|
      t.datetime :published_at
      t.string :announcement_type
      t.string :name
      t.text :description

      t.timestamps
    end
  end
end
