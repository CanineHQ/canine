class AddAccessTokenToStackManager < ActiveRecord::Migration[7.2]
  def change
    add_column :stack_managers, :access_token, :string
  end
end
