class AddContainerPortToServices < ActiveRecord::Migration[7.2]
  def change
    add_column :services, :container_port, :integer, default: 3000
  end
end
