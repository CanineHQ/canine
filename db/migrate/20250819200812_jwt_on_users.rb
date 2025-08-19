class JwtOnUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :jwt, :string
    add_column :users, :username, :string
  end
end
