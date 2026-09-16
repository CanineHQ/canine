class AddInternalAuthProxySupport < ActiveRecord::Migration[7.2]
  def change
    add_column :services, :internal, :boolean, default: false
    add_column :add_ons, :internal, :boolean, default: false
    add_reference :oauth_applications, :service, foreign_key: true, index: { unique: true }
    add_reference :oauth_applications, :add_on, foreign_key: true, index: { unique: true }, null: true
  end
end
