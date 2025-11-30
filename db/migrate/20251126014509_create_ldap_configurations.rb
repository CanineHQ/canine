class CreateLDAPConfigurations < ActiveRecord::Migration[7.2]
  def change
    create_table :ldap_configurations do |t|
      t.string :host, null: false
      t.integer :port, default: 389, null: false
      t.integer :encryption, null: false
      t.string :base_dn, null: false
      t.string :bind_dn
      t.string :bind_password
      t.string :uid_attribute, default: "uid", null: false
      t.string :email_attribute, default: "mail"
      t.string :name_attribute, default: "cn"
      t.string :filter
      t.boolean :allow_anonymous_reads, default: false
      t.string :reader_dn
      t.string :reader_password

      t.timestamps
    end
  end
end
