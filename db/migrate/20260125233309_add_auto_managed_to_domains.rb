class AddAutoManagedToDomains < ActiveRecord::Migration[7.2]
  def change
    add_column :domains, :auto_managed, :boolean, default: false
  end
end
