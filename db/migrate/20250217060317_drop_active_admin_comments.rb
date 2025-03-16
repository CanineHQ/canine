class DropActiveAdminComments < ActiveRecord::Migration[7.2]
  def change
    drop_table :active_admin_comments
  end
end
