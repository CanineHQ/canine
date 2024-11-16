class AddStatusToDomains < ActiveRecord::Migration[7.2]
  def change
    add_column :domains, :status, :integer, default: 0
    add_column :domains, :status_reason, :string
  end
end
