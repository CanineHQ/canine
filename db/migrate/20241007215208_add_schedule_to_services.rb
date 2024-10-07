class AddScheduleToServices < ActiveRecord::Migration[7.2]
  def change
    add_column :services, :schedule, :string
  end
end
