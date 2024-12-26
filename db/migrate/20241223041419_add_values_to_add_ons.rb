class AddValuesToAddOns < ActiveRecord::Migration[7.2]
  def change
    add_column :add_ons, :values, :jsonb, default: {}
  end
end
