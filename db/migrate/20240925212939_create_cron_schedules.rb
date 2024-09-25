class CreateCronSchedules < ActiveRecord::Migration[7.2]
  def change
    create_table :cron_schedules do |t|
      t.references :service, null: false, foreign_key: true
      t.string :schedule, null: false
    end
  end
end
