class RemoveInternalFromServicesAndAddOns < ActiveRecord::Migration[7.2]
  def change
    remove_column :services, :internal, :boolean, default: false
    remove_column :add_ons, :internal, :boolean, default: false
  end
end
