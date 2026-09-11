class AddInternalToServices < ActiveRecord::Migration[7.2]
  def change
    add_column :services, :internal, :boolean, default: false
    add_reference :oauth_applications, :service, foreign_key: true, index: { unique: true }
  end
end
